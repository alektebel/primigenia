import assert from 'node:assert/strict';
import {waitForEnvironment} from '../web/stage/boot.js';
const host=new EventTarget();host.__stageWorld={};
const result=waitForEnvironment(host,200);
// Firefox fires load while an async module is still awaiting WASM.
host.dispatchEvent(new Event('load'));
setTimeout(()=>{host.__stageEnvironment={ready:true}},40);
assert.equal(await result,host.__stageEnvironment);
assert.equal(await waitForEnvironment(host),host.__stageEnvironment);
await assert.rejects(waitForEnvironment(new EventTarget(),10),/timed out/);
const failure=new EventTarget(),pending=waitForEnvironment(failure,100);
const event=new Event('unhandledrejection');event.reason=Error('WASM download failed');failure.dispatchEvent(event);
await assert.rejects(pending,/WASM download failed/);
const scriptHost=new EventTarget(),scriptPending=waitForEnvironment(scriptHost,100),scriptError=new Event('error');scriptError.message='WebGL unavailable';scriptHost.dispatchEvent(scriptError);
await assert.rejects(scriptPending,/WebGL unavailable/);
console.log('PASS async environment readiness, timeout and visible startup errors');
