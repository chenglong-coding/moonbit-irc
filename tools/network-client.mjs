import net from 'node:net';
import tls from 'node:tls';
import {EventEmitter} from 'node:events';
import {randomUUID} from 'node:crypto';
import {session_open,session_receive,session_status,session_close,validate_outgoing} from '../web/engine.mjs';

/** Node transport for the compiled MoonBit registration/IRCv3 core. No implicit channel joins or messages. */
export class IrcClient extends EventEmitter {
  #socket; #key; #buffer=Buffer.alloc(0); #timer; #retryTimer; #stopped=false; #started=false; #attempts=0; #resolve; #reject; #ready=false;
  constructor(options={}) {
    super();
    this.options={port:options.tls===false?6667:6697,tls:true,nick:'moonbit',user:'moonbit',realname:'MoonBit IRC',capabilities:[],registrationTimeoutMs:15000,idleTimeoutMs:120000,maxReconnects:0,reconnectDelayMs:250,...options};
    const o=this.options;
    for(const name of ['nick','user','realname'])if(typeof o[name]!=='string')throw new Error('Invalid '+name);
    if(typeof o.tls!=='boolean')throw new Error('Invalid TLS option');
    if(typeof o.host!=='string'||!o.host||!Number.isInteger(o.port)||o.port<1||o.port>65535)throw new Error('Valid host and port required');
    for(const name of ['registrationTimeoutMs','idleTimeoutMs','reconnectDelayMs'])if(!Number.isFinite(o[name])||o[name]<1||o[name]>2147483647)throw new Error('Invalid '+name);
    if(!Number.isInteger(o.maxReconnects)||o.maxReconnects<0||o.maxReconnects>100)throw new Error('Invalid maxReconnects');
    if(!Array.isArray(o.capabilities)||o.capabilities.some(x=>typeof x!=='string'||/\s/.test(x)))throw new Error('Invalid capabilities');
  }
  get status(){return this.#key?session_status(this.#key):'closed'}
  connect(){
    if(this.#started)return Promise.reject(new Error('Client already started'));
    this.#started=true;
    return new Promise((resolve,reject)=>{this.#resolve=resolve;this.#reject=reject;this.#connect()});
  }
  #connect(){
    if(this.#stopped)return;
    this.#key=randomUUID();this.#buffer=Buffer.alloc(0);this.#ready=false;
    const o=this.options;
    const initial=session_open(this.#key,o.nick,o.user,o.realname,o.capabilities.join(' '));
    if(initial.startsWith('ERROR:')){session_close(this.#key);this.#key=undefined;this.#reject?.(new Error(initial));this.#reject=undefined;return}
    const socket=o.tls?tls.connect({host:o.host,port:o.port,servername:o.servername??(net.isIP(o.host)?undefined:o.host),ca:o.ca,rejectUnauthorized:true}):net.connect({host:o.host,port:o.port});
    this.#socket=socket;
    this.#timer=setTimeout(()=>socket.destroy(new Error('Registration timeout')),o.registrationTimeoutMs);
    socket.setTimeout(o.idleTimeoutMs,()=>socket.destroy(new Error('Idle timeout')));
    socket.once(o.tls?'secureConnect':'connect',()=>this.#write(initial));
    socket.on('data',chunk=>{
      try{
        // At most one incomplete IRC line is retained; UTF-8 is decoded only after CRLF.
        for(let offset=0;offset<chunk.length;){
          const end=chunk.indexOf(10,offset),stop=end<0?chunk.length:end+1;
          const piece=chunk.subarray(offset,stop);offset=stop;
          if(this.#buffer.length+piece.length>8194)throw new Error('IRC line limit');
          this.#buffer=Buffer.concat([this.#buffer,piece]);
          if(end<0)break;
          if(this.#buffer.length<2||this.#buffer.at(-2)!==13)throw new Error('Expected CRLF');
          const line=new TextDecoder('utf-8',{fatal:true}).decode(this.#buffer.subarray(0,-2));this.#buffer=Buffer.alloc(0);
          const wire=session_receive(this.#key,line);
          if(wire.startsWith('ERROR:'))throw new Error(wire);
          if(wire)this.#write(wire);
          if(!this.#ready&&this.status==='registered'){
            this.#ready=true;clearTimeout(this.#timer);this.#resolve?.(this);this.#resolve=undefined;this.#reject=undefined;this.emit('registered');
          }
          this.emit('message',line);
        }
      }catch(error){socket.destroy(error)}
    });
    socket.on('end',()=>{if(this.#buffer.length)socket.destroy(new Error('Truncated IRC stream'))});
    let failure;
    socket.on('error',error=>{failure=error;this.emit('fault',error)});
    socket.on('close',()=>{
      clearTimeout(this.#timer);session_close(this.#key);this.#key=undefined;this.#socket=undefined;
      this.emit('disconnected',failure);
      if(!this.#stopped&&this.#attempts<o.maxReconnects){
        const delay=Math.min(o.reconnectDelayMs*2**this.#attempts,30000);this.#attempts++;
        this.#retryTimer=setTimeout(()=>this.#connect(),delay);
      }else{this.#reject?.(failure??new Error('Connection closed before registration'));this.#reject=undefined}
    });
  }
  #write(wire){
    if(!this.#socket||this.#socket.destroyed)throw new Error('Connection closed');
    if(this.#socket.writableLength+Buffer.byteLength(wire)>1048576){const error=new Error('Outgoing queue limit');this.#socket.destroy(error);throw error}
    this.#socket.write(wire);
  }
  send(line){
    if(this.status!=='registered')throw new Error('Not registered');
    const wire=validate_outgoing(line);
    if(wire.startsWith('ERROR:'))throw new Error(wire);
    this.#write(wire);
  }
  close(){
    this.#stopped=true;clearTimeout(this.#retryTimer);clearTimeout(this.#timer);
    this.#reject?.(new Error('Client closed'));this.#reject=undefined;
    this.#socket?.destroy();
  }
}
