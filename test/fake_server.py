#!/usr/bin/env python3
"""A stand-in for gocov's upload endpoint, for test/e2e.sh.

Answers POST /api/v1/upload the way the real server does on success
(201 + the JSON the CLI prints from) and writes what it received —
the Authorization header and every multipart field — to <out>/request.json,
so the test can assert on what the pinned CLI actually sent.

    fake_server.py <port> <out-dir>
"""
import email.parser
import email.policy
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port, out = int(sys.argv[1]), sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/api/v1/upload":
            self.send_error(404)
            return
        body = self.rfile.read(int(self.headers["Content-Length"]))
        msg = email.parser.BytesParser(policy=email.policy.HTTP).parsebytes(
            b"Content-Type: " + self.headers["Content-Type"].encode() + b"\r\n\r\n" + body)
        fields = {}
        for part in msg.iter_parts():
            fields[part.get_param("name", header="content-disposition")] = \
                part.get_payload(decode=True).decode()
        with open(os.path.join(out, "request.json"), "w") as f:
            json.dump({"authorization": self.headers.get("Authorization", ""),
                       "fields": fields}, f, indent=2)
        resp = json.dumps({"id": 1, "total_pct": 75.0, "covered_stmts": 3,
                           "total_stmts": 4, "build_status": "posted"}).encode()
        self.send_response(201)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(resp)))
        self.end_headers()
        self.wfile.write(resp)

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", port), Handler).serve_forever()
