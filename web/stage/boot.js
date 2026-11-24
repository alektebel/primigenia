// Firefox can dispatch window.load while the environment module still awaits
// WASM. Readiness belongs to the environment, not to the document load event.
export function waitForEnvironment(host=window,timeout=30000){
 if(host.__stageEnvironment&&host.__stageWorld)return Promise.resolve(host.__stageEnvironment);
 return new Promise((resolve,reject)=>{
  const cleanup=()=>{clearInterval(poll);clearTimeout(timer);host.removeEventListener('error',failed);host.removeEventListener('unhandledrejection',failed)};
  const failed=event=>{const error=event.reason||event.error||event.message;if(error){cleanup();reject(error instanceof Error?error:Error(String(error)))}};
  const poll=setInterval(()=>{if(host.__stageEnvironment&&host.__stageWorld){cleanup();resolve(host.__stageEnvironment)}},20);
  const timer=setTimeout(()=>{cleanup();reject(Error('Valley environment timed out while loading terrain or WebGL'))},timeout);
  host.addEventListener('error',failed);host.addEventListener('unhandledrejection',failed);
 });
}
