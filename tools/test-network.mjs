import {test} from 'node:test';
import assert from 'node:assert/strict';
import net from 'node:net';
import tls from 'node:tls';
import {once} from 'node:events';
import {spawnSync} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {IrcClient} from './network-client.mjs';

async function fixture(t, handler, secure) {
  const sockets=new Set();let connections=0;
  const accept=socket=>{sockets.add(socket);socket.on('error',()=>{});socket.on('close',()=>sockets.delete(socket));handler(socket,++connections)};
  const server=secure?tls.createServer(secure,accept):net.createServer(accept);
  server.on('tlsClientError',()=>{});
  server.listen(0,'127.0.0.1');await once(server,'listening');
  t.after(async()=>{for(const s of sockets)s.destroy();await new Promise(resolve=>server.close(resolve))});
  return {port:server.address().port,get connections(){return connections}};
}
function readLines(socket,callback){let buffer='';socket.on('data',chunk=>{buffer+=chunk.toString();let i;while((i=buffer.indexOf('\r\n'))>=0){const line=buffer.slice(0,i);buffer=buffer.slice(i+2);callback(line)}})}
function client(t,port,extra={}){const c=new IrcClient({host:'127.0.0.1',port,tls:false,nick:'tester',registrationTimeoutMs:1000,idleTimeoutMs:2000,...extra});t.after(()=>c.close());return c}

await test('real TCP: fragmented CAP 302, PING, Unicode and application send', {timeout:5000},async t=>{
  const received=[];let peer;
  const f=await fixture(t,s=>{peer=s;readLines(s,line=>{received.push(line);if(line.startsWith('USER ')){s.write('CAP * LS * :server-time\r');setTimeout(()=>s.write('\nCAP * LS :multi-prefix\r\n'),5)}if(line==='CAP REQ server-time')s.write('CAP * ACK server-time\r\n');if(line==='CAP REQ multi-prefix')s.write('CAP * NAK multi-prefix\r\n');if(line==='CAP END')s.write(':server 001 tester :Welcome\r\n')})});
  const c=client(t,f.port,{capabilities:['server-time','multi-prefix']});await c.connect();
  assert.equal(c.status,'registered');assert.equal(received.filter(x=>x==='CAP END').length,1);
  const message=once(c,'message');const unicode=Buffer.from(':s PRIVMSG tester :你好\r\n');peer.write(unicode.subarray(0,21));peer.write(unicode.subarray(21));assert.match((await message)[0],/你好/);
  const pong=new Promise(resolve=>{const timer=setInterval(()=>{if(received.includes('PONG check')){clearInterval(timer);resolve()}},5);t.after(()=>clearInterval(timer))});
  peer.write('PING check\r\n');await pong;
  const application=once(peer,'data');c.send('PRIVMSG #local :test');assert.equal((await application)[0].toString(),'PRIVMSG #local test\r\n');assert.throws(()=>c.send('PRIVMSG #local :x\r\nQUIT'),/ERROR/);
  assert.deepEqual(received.slice(0,2),['CAP LS 302','NICK tester']);
});
await test('legacy server without CAP registers', {timeout:3000},async t=>{
  const f=await fixture(t,s=>readLines(s,line=>{if(line.startsWith('USER '))s.write(':s 421 tester CAP :unknown\r\n:s 001 tester :Welcome\r\n')}));
  await client(t,f.port).connect();
});
await test('registration rejection closes and rejects connect', {timeout:3000},async t=>{
  const f=await fixture(t,s=>s.write(':s 433 tester nick :in use\r\n'));
  await assert.rejects(client(t,f.port).connect(),/433/);
});
await test('registration timeout bounds silent peer', {timeout:3000},async t=>{
  const f=await fixture(t,()=>{});await assert.rejects(client(t,f.port,{registrationTimeoutMs:40}).connect(),/Registration timeout/);
});
await test('reconnect creates fresh MoonBit session and repeats registration', {timeout:4000},async t=>{
  const f=await fixture(t,(s,n)=>readLines(s,line=>{if(line.startsWith('USER ')){if(n===1)s.destroy();else s.write(':s 001 tester :Welcome\r\n')}}));
  await client(t,f.port,{maxReconnects:1,reconnectDelayMs:10}).connect();assert.equal(f.connections,2);
});
await test('malformed UTF8, bare LF, overlong and truncated stream reject', {timeout:4000},async t=>{
  for(const bytes of [Buffer.from([255,13,10]),Buffer.from('PING x\n'),Buffer.alloc(8200,65),Buffer.from('PING incomplete')]){
    const f=await fixture(t,s=>s.end(bytes));await assert.rejects(client(t,f.port).connect());
  }
});
await test('manual close cancels registration and retry', {timeout:3000},async t=>{
  const f=await fixture(t,()=>{});const c=client(t,f.port,{maxReconnects:5});const pending=c.connect();c.close();await assert.rejects(pending,/Client closed/);
});
await test('TLS verifies certificate trust and hostname', {timeout:10000},async t=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'moonbit-irc-tls-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
  const openssl=process.env.OPENSSL??(process.platform==='win32'&&fs.existsSync('C:/Program Files/Git/usr/bin/openssl.exe')?'C:/Program Files/Git/usr/bin/openssl.exe':'openssl');
  const key=path.join(dir,'key.pem'),cert=path.join(dir,'cert.pem');
  const result=spawnSync(openssl,['req','-x509','-newkey','rsa:2048','-nodes','-keyout',key,'-out',cert,'-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost'],{encoding:'utf8',timeout:8000});assert.equal(result.status,0,result.stderr);
  const ca=fs.readFileSync(cert);
  const f=await fixture(t,s=>readLines(s,line=>{if(line.startsWith('USER '))s.write(':s 001 tester :Welcome\r\n')}),{key:fs.readFileSync(key),cert:ca});
  await client(t,f.port,{tls:true,ca,servername:'localhost'}).connect();
  await assert.rejects(client(t,f.port,{tls:true,servername:'localhost'}).connect());
  await assert.rejects(client(t,f.port,{tls:true,ca,servername:'wrong.local'}).connect(),/Hostname|altnames/);
});

await test('idle timeout after registration disconnects cleanly', {timeout:3000},async t=>{
  const f=await fixture(t,s=>readLines(s,line=>{if(line.startsWith('USER '))s.write(':s 001 tester :Welcome\r\n')}));
  const c=client(t,f.port,{idleTimeoutMs:40});await c.connect();const [error]=await once(c,'disconnected');assert.match(error.message,/Idle timeout/);
});

await test('TLS SASL PLAIN chunks and PASS succeed only after authentication', {timeout:10000},async t=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'moonbit-irc-tls-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
  const openssl=process.env.OPENSSL??(process.platform==='win32'&&fs.existsSync('C:/Program Files/Git/usr/bin/openssl.exe')?'C:/Program Files/Git/usr/bin/openssl.exe':'openssl');
  const key=path.join(dir,'key.pem'),cert=path.join(dir,'cert.pem');
  const result=spawnSync(openssl,['req','-x509','-newkey','rsa:2048','-nodes','-keyout',key,'-out',cert,'-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost'],{encoding:'utf8',timeout:8000});assert.equal(result.status,0,result.stderr);
  const ca=fs.readFileSync(cert);

  for(const result of ['903','904','001']) {
    const seen=[];let chunks='';
    const password='假密码'.repeat(80);
    const f=await fixture(t,s=>readLines(s,line=>{
      seen.push(line);
      if(line.startsWith('USER '))s.write('CAP * LS :sasl=PLAIN\r\n');
      if(line==='CAP REQ sasl')s.write('CAP * ACK sasl\r\n');
      if(line==='AUTHENTICATE PLAIN')s.write('AUTHENTICATE +\r\n');
      else if(line.startsWith('AUTHENTICATE ')){
        const chunk=line.slice(13);if(chunk!=='+')chunks+=chunk;
        assert.ok(chunk.length<=400);
        if(chunk==='+'||chunk.length<400){
          assert.equal(Buffer.from(chunks,'base64').toString('utf8'),'\0tester\0'+password);
          assert.ok(!seen.includes('CAP END'));
          s.write(':s '+result+' tester :result\r\n');
        }
      }
      if(line==='CAP END')s.write(':s 001 tester :Welcome\r\n');
    }),{key:fs.readFileSync(key),cert:ca});
    const c=client(t,f.port,{tls:true,ca,servername:'localhost',serverPassword:'local-fixture-password',sasl:{username:'tester',password}});
    if(result==='903'){await c.connect();assert.equal(c.status,'registered');assert.ok(seen.includes('CAP END'))}
    else await assert.rejects(c.connect(),result==='904'?/904/:/before required authentication/);
    assert.equal(seen[0],'PASS local-fixture-password');
    assert.ok(seen.filter(x=>x.startsWith('AUTHENTICATE ')).length>=3);
    c.close();
  }
});
await test('credential options require TLS and reject malformed input',()=>{
  assert.throws(()=>new IrcClient({host:'localhost',tls:false,sasl:{username:'u',password:'p'}}),/require TLS/);
  assert.throws(()=>new IrcClient({host:'localhost',tls:false,serverPassword:'p'}),/require TLS/);
  assert.throws(()=>new IrcClient({host:'localhost',sasl:{username:'',password:'p'}}),/Invalid SASL/);
});
