#!/usr/bin/env python3
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/prompt":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        if length:
            json.loads(self.rfile.read(length).decode("utf-8"))
        self._send_json({"prompt_id": "mock-prompt-1"})

    def do_GET(self):
        if self.path != "/history/mock-prompt-1":
            self.send_error(404)
            return
        self._send_json({
            "mock-prompt-1": {
                "outputs": {
                    "save_front": {
                        "images": [{
                            "filename": "front.png",
                            "subfolder": "character_turnaround/mock",
                            "type": "output",
                        }]
                    }
                }
            }
        })

    def log_message(self, _format, *_args):
        return

    def _send_json(self, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: mock_comfyui_server.py PORT_FILE")
    port_file = Path(sys.argv[1])
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    port_file.write_text(str(server.server_address[1]) + "\n")
    server.serve_forever()


if __name__ == "__main__":
    main()
