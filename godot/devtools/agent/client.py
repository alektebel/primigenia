"""Stdlib-only client for the Godot agent socket (godot/devtools/agent/PROTOCOL.md).

    with GodotAgent("godot", scenario="creature/garfio_close") as g:
        g.send("console", text="god on")
        r = g.send("step", ticks=50)
"""
import json
import os
import socket
import subprocess
import time


class AgentError(RuntimeError):
    pass


class GodotAgent:
    def __init__(self, godot="godot", project=None, scenario=None, port=47110, headless=True, extra=(), timeout=120):
        here = os.path.dirname(os.path.abspath(__file__))
        self.project = project or os.path.normpath(os.path.join(here, "..", ".."))
        args = [godot] + (["--headless"] if headless else []) + ["--path", self.project, "--"]
        args += ["--agent", "--agent-port=%d" % port]
        if scenario:
            args += ["--scenario", scenario]
        args += list(extra)
        self.port, self.timeout, self.events, self._id = port, timeout, [], 0
        self.proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        self.ready, self.log = None, []
        deadline = time.time() + timeout
        while time.time() < deadline:
            line = self.proc.stdout.readline()
            if not line:
                raise AgentError("godot exited before AGENT_READY:\n" + "\n".join(self.log[-20:]))
            self.log.append(line.rstrip())
            if line.startswith("AGENT_READY "):
                self.ready = json.loads(line[len("AGENT_READY "):])
                break
            if line.startswith("AGENT_ERROR") or line.startswith("SCENARIO_ERROR"):
                raise AgentError(line.strip())
        if not self.ready:
            raise AgentError("timeout waiting for AGENT_READY")
        self.sock = socket.create_connection(("127.0.0.1", port), timeout=timeout)
        self._buf = b""

    def send(self, cmd, **kw):
        """One request, returns the response; pushed events are collected in self.events."""
        self._id += 1
        req = dict(kw, cmd=cmd, id=self._id)
        self.sock.sendall((json.dumps(req) + "\n").encode())
        while True:
            while b"\n" not in self._buf:
                chunk = self.sock.recv(65536)
                if not chunk:
                    raise AgentError("socket closed")
                self._buf += chunk
            line, self._buf = self._buf.split(b"\n", 1)
            msg = json.loads(line)
            if "event" in msg:
                self.events.append(msg)
            elif msg.get("id") == self._id:
                return msg

    def close(self):
        try:
            self.send("quit")
        except Exception:
            pass
        try:
            self.proc.wait(timeout=20)
        except Exception:
            self.proc.kill()

    def __enter__(self):
        return self

    def __exit__(self, *a):
        self.close()
