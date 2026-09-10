// Optional independent implementation test. ERGO_HOME must contain Ergo 2.19.1 and default.yaml.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import net from 'node:net';
import {spawn,spawnSync} from 'node:child_process';
import {once} from 'node:events';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {IrcClient} from './network-client.mjs';
const home=process.env.ERGO_HOME;
assert.ok(home,'Set ERGO_HOME to the extracted official Ergo 2.19.1 distribution');
const exe=path.resolve(home,process.platform==='win32'?'ergo.exe':'ergo');
const version=spawnSync(exe,['--version'],{encoding:'utf8',windowsHide:true});assert.equal(version.status,0);assert.match(version.stdout,/2\.19\.1/);
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'moonbit-ergo-'));
let daemon;const clients=[];
function waitMessage(c,match){return new Promise((resolve,reject)=>{const timer=setTimeout(()=>{c.off('message',onMessage);reject(new Error('Expected Ergo response timed out'))},5000);function onMessage(line){if(match(line)){clearTimeout(timer);c.off('message',onMessage);resolve(line)}}c.on('message',onMessage)})}
try{
  const reservation=net.createServer();reservation.listen(0,'127.0.0.1');await once(reservation,'listening');const port=reservation.address().port;await new Promise(resolve=>reservation.close(resolve));
  let config=fs.readFileSync(path.resolve(home,'default.yaml'),'utf8');
  config=config.replace(/    listeners:\r?\n[\s\S]*?(?=    # sets the permissions)/,`    listeners:\n        "127.0.0.1:${port}":\n            tls:\n                cert: fullchain.pem\n                key: privkey.pem\n\n`);
  config=config.replace('    path: languages','    path: '+JSON.stringify(path.resolve(home,'languages').replaceAll('\\','/')));
  fs.writeFileSync(path.join(dir,'ircd.yaml'),config);
  fs.copyFileSync(path.resolve(home,'ergo.motd'),path.join(dir,'ergo.motd'));
  const cert=spawnSync(exe,['mkcerts'],{cwd:dir,encoding:'utf8',windowsHide:true,timeout:10000});assert.equal(cert.status,0,cert.stderr);
  daemon=spawn(exe,['run'],{cwd:dir,windowsHide:true,stdio:['ignore','pipe','pipe']});
  await new Promise((resolve,reject)=>{
    let output='';const timer=setTimeout(()=>reject(new Error('Ergo startup timeout')),10000);
    const collect=chunk=>{output=(output+chunk.toString()).slice(-20000);if(output.includes('Server running')){clearTimeout(timer);resolve()}};
    daemon.stdout.on('data',collect);daemon.stderr.on('data',collect);daemon.once('error',reject);daemon.once('exit',code=>{clearTimeout(timer);reject(new Error('Ergo exited '+code))});
  });
  const ca=fs.readFileSync(path.join(dir,'fullchain.pem'));
  const account='test'+Date.now(),password='Local-fixture-only-456';
  function make(nick,sasl){const c=new IrcClient({host:'127.0.0.1',port,ca,servername:'ergo.test',nick,capabilities:['server-time','multi-prefix'],sasl,registrationTimeoutMs:5000});clients.push(c);return c}
  const registrar=make(account);await registrar.connect();
  const created=waitMessage(registrar,line=>line.includes('NickServ')&&line.includes('Account created'));
  registrar.send('PRIVMSG NickServ :REGISTER '+password);await created;
  const closed=once(registrar,'disconnected');registrar.close();await closed;
  const auth=make(account,{username:account,password});const numerics=[];auth.on('message',line=>{if(/ 90[03] /.test(line))numerics.push(line.match(/ (90[03]) /)[1])});await auth.connect();
  assert.ok(numerics.includes('903'));assert.equal(auth.status,'registered');
  const guest=make('peer'+Date.now());await guest.connect();
  const delivered=waitMessage(guest,line=>line.includes('PRIVMSG')&&line.endsWith(':独立服务端互通'));
  auth.send('PRIVMSG '+guest.options.nick+' :独立服务端互通');const line=await delivered;assert.ok(line.startsWith('@time='),'server-time capability must be active');
  const bad=make('bad'+Date.now(),{username:account,password:'incorrect-fixture-password'});await assert.rejects(bad.connect(),/904/);
  const evidence={oracle:version.stdout.trim(),binary_sha256:createHash('sha256').update(fs.readFileSync(exe)).digest('hex'),timestamp:new Date().toISOString(),scope:'Local isolated Ergo daemon over verified TLS; temporary database and synthetic account',checks:['CAP 302 and registration','NickServ account creation','SASL PLAIN success numeric 903','Unicode PRIVMSG to second local client','server-time tag','wrong password rejected with 904'],passed:6};
  fs.mkdirSync(new URL('../evidence/',import.meta.url),{recursive:true});fs.writeFileSync(new URL('../evidence/ergo-interop.json',import.meta.url),JSON.stringify(evidence,null,2)+'\n');console.log('Ergo 2.19.1: 6 independent daemon checks passed');
}finally{
  for(const c of clients)c.close();
  if(daemon&&daemon.exitCode===null){const exited=once(daemon,'exit');daemon.kill();await exited}
  fs.rmSync(dir,{recursive:true,force:true});
}
