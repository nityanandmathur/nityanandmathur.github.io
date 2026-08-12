"""Single-port static server with poll-based auto-reload.

Serves the folder this file lives in on http://127.0.0.1:8000 and injects a
tiny JS snippet into every HTML response that polls /__mtime once per second.
When the max mtime of watched files changes, the browser reloads itself.

No WebSocket, no extra port - works through cloudflared / any HTTP proxy.
Override the port with `PORT=8123 python3 serve.py`.
"""
from __future__ import annotations

import json
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

DOCS = os.path.dirname(os.path.abspath(__file__))
PORT = int(os.environ.get("PORT", "8000"))

WATCH_EXTS = {".html", ".css", ".js", ".wav", ".mp3", ".png", ".jpg", ".svg", ".json"}

RELOAD_JS = b"""
<script>
(function(){
  let last = null;
  async function poll(){
    try {
      const r = await fetch('/__mtime', {cache:'no-store'});
      if (!r.ok) return;
      const {mtime} = await r.json();
      if (last === null) { last = mtime; return; }
      if (mtime !== last) { location.reload(); }
    } catch (e) {}
  }
  setInterval(poll, 1000);
})();
</script>
"""


def max_mtime() -> float:
    latest = 0.0
    for root, _dirs, files in os.walk(DOCS):
        for f in files:
            if f.startswith("."):
                continue
            ext = os.path.splitext(f)[1].lower()
            if ext not in WATCH_EXTS:
                continue
            try:
                m = os.path.getmtime(os.path.join(root, f))
                if m > latest:
                    latest = m
            except OSError:
                pass
    return latest


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=DOCS, **kw)

    def log_message(self, fmt, *args):  # quieter logs
        pass

    def do_GET(self):
        if self.path == "/__mtime":
            body = json.dumps({"mtime": max_mtime()}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        path = self.translate_path(self.path)
        if os.path.isdir(path):
            index = os.path.join(path, "index.html")
            if os.path.exists(index):
                path = index
        if path.endswith(".html") and os.path.isfile(path):
            with open(path, "rb") as f:
                data = f.read()
            if b"</body>" in data:
                data = data.replace(b"</body>", RELOAD_JS + b"</body>", 1)
            else:
                data = data + RELOAD_JS
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return

        # default static handling for everything else (audio, images, css, js)
        super().do_GET()


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Serving {DOCS} on http://127.0.0.1:{PORT} (poll-reload enabled)")
    srv.serve_forever()
