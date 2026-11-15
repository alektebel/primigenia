"""Installed Firefox + raw Marionette; no driver or system packages required.
Delay WASM to exercise Firefox's load event preceding top-level-await completion.
Only the server response receives a frozen animation clock; production is unchanged.
"""
import functools
import http.server
import json
import os
import pathlib
import socket
import subprocess
import tempfile
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = pathlib.Path(os.environ.get('CPORE_CAMERA_EVIDENCE', ROOT / 'docs/evidence/stage/camera'))

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        if self.path.endswith('cpore_world.wasm'):
            time.sleep(2)
        if self.path == '/web/stage/':
            html = (ROOT / 'web/stage/index.html').read_text().replace('<head>', '''<head><script>
window.__stageTesting=true;requestAnimationFrame=f=>1;
window.__bootErrors=[];addEventListener('error',e=>__bootErrors.push(e.message));
addEventListener('unhandledrejection',e=>__bootErrors.push(String(e.reason)));
</script>''', 1).encode()
            self.send_response(200); self.send_header('Content-Type', 'text/html'); self.end_headers(); self.wfile.write(html)
        else:
            super().do_GET()

class Marionette:
    def __init__(self, sock): self.sock, self.seq = sock, 0; self.read()
    def read(self):
        header = b''
        while not header.endswith(b':'):
            chunk=self.sock.recv(1)
            if not chunk: raise ConnectionError('Firefox closed the Marionette connection')
            header += chunk
        body = b''
        while len(body) < int(header[:-1]):
            chunk=self.sock.recv(int(header[:-1])-len(body))
            if not chunk: raise ConnectionError('Firefox closed the Marionette response')
            body += chunk
        return json.loads(body)
    def call(self, name, args=None):
        self.seq += 1
        body = json.dumps([0,self.seq,name,args or {}]).encode()
        self.sock.sendall(str(len(body)).encode()+b':'+body)
        result = self.read()
        if result[2]: raise RuntimeError(result[2])
        return result[3]
    def evaluate(self, script): return self.call('WebDriver:ExecuteScript', {'script':script,'args':[]})['value']

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    server = http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT)))
    thread = threading.Thread(target=server.serve_forever,daemon=True); thread.start()
    with tempfile.TemporaryDirectory(prefix='cpore-firefox-') as profile:
        with socket.socket() as probe:
            probe.bind(('127.0.0.1',0)); port=probe.getsockname()[1]
        pathlib.Path(profile,'user.js').write_text(f'user_pref("marionette.port", {port});\nuser_pref("gfx.webrender.software", true);\nuser_pref("layers.acceleration.disabled", true);\n')
        with (OUT/'firefox.log').open('w') as log:
            proc=subprocess.Popen(['/usr/bin/firefox','--headless','--no-remote','--marionette','--profile',profile,'about:blank'],stdout=log,stderr=log)
            client=None
            try:
                for _ in range(100):
                    try: sock=socket.create_connection(('127.0.0.1',port),timeout=1);break
                    except OSError: time.sleep(.1)
                else: raise RuntimeError('Firefox Marionette did not start')
                sock.settimeout(90);client=Marionette(sock)
                session=client.call('WebDriver:NewSession',{'capabilities':{}})
                client.call('WebDriver:Navigate',{'url':f'http://127.0.0.1:{server.server_port}/web/stage/'})
                result=None
                for _ in range(200):
                    result=client.evaluate('return {ready:!!window.Stage?.ready,env:!!window.__stageEnvironment,status:document.getElementById("status").textContent,errors:window.__bootErrors};')
                    if result['ready'] or 'could not open' in result['status']: break
                    time.sleep(.1)
                result['browser']=session['capabilities']['browserVersion'];result['delayedWasmSeconds']=2
                (OUT/'firefox-results.json').write_text(json.dumps(result,indent=2)+'\n')
                print(json.dumps(result));assert result['ready'] and not result['errors'], result
                tick=client.evaluate('Stage.frame(.1);return Stage.simulation.ticks;')
                assert tick==1, tick
                print('PASS installed Firefox boots with delayed WASM and advances the C world')
            finally:
                if client:
                    try: client.call('Marionette:Quit',{'flags':['eForceQuit']})
                    except (OSError,RuntimeError): pass
                if proc.poll() is None: proc.terminate()
                try: proc.wait(timeout=10)
                except subprocess.TimeoutExpired: proc.kill();proc.wait()
                server.shutdown();server.server_close()

if __name__=='__main__': main()
