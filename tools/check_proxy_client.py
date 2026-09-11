import json
import os
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if self.path == "/timeout":
            time.sleep(0.5)
        status = int(self.path.rsplit("/", 1)[-1]) if self.path.startswith("/status/") else 200
        content = "OK" if request.get("model") == "mistralai/mistral-medium-3-5" and request.get("max_tokens") == 50 else "BAD REQUEST"
        body = json.dumps({"choices": [{"message": {"content": content}}]}).encode()
        if self.path == "/malformed":
            body = b"not json"
        if self.path == "/empty":
            body = b'{"choices":[]}'
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass


def main():
    with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        env = dict(os.environ, TEST_PROXY_URL=f"http://127.0.0.1:{server.server_port}")
        try:
            return subprocess.run([sys.argv[1], "--headless", "--path", "game/godot", "-s", "res://tests/run_client_tests.gd"], env=env, timeout=30).returncode
        finally:
            server.shutdown()
            worker.join()


if __name__ == "__main__":
    raise SystemExit(main())
