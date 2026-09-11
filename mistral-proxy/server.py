#!/usr/bin/env python3
"""Local OpenAI-compatible proxy pooling OpenRouter keys for cheap Mistral tasks.

Stdlib only — no pip install needed. One teammate collects the redeemed
OpenRouter keys into keys.json (see keys.json.example), everyone on the
team starts this proxy on their own machine and points their agent at
http://127.0.0.1:8377/v1.
"""

import argparse
import hashlib
import json
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
KEYS_FILE = HERE / "keys.json"
USAGE_FILE = HERE / "usage.jsonl"
CACHE_FILE = HERE / "cache.jsonl"
CACHE_MAX_ENTRIES = 5000

HOST = "127.0.0.1"
DEFAULT_PORT = 8377
DEFAULT_MODEL = "mistralai/mistral-medium-3-5"
DEFAULT_BUDGET = 19.0  # safety cap, $ per key; keys carry a $20 budget
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

STATE = {"lock": threading.Lock(), "keys": [], "spend": {}, "requests": {}, "next": 0,
         "cache": {}, "cache_hits": 0}


def log(msg):
    print(f"[mistral-proxy] {msg}", flush=True)


def mask(key):
    return key[:12] + "..." if len(key) > 12 else "***"


def load_state():
    if not KEYS_FILE.exists():
        raise SystemExit(
            f"keys.json not found. Copy keys.json.example to keys.json and paste "
            f"your redeemed OpenRouter keys. Redeem: https://hackathon.ars.electronica.art/redeem"
        )
    cfg = json.loads(KEYS_FILE.read_text(encoding="utf-8"))
    STATE["keys"] = cfg["keys"]
    STATE["budget"] = float(cfg.get("budget_usd", DEFAULT_BUDGET))
    for k in STATE["keys"]:
        STATE["spend"][k] = 0.0
        STATE["requests"][k] = 0
    # Replay usage log so budgets survive restarts.
    if USAGE_FILE.exists():
        for line in USAGE_FILE.read_text(encoding="utf-8").splitlines():
            try:
                rec = json.loads(line)
                STATE["spend"][rec["key"]] = STATE["spend"].get(rec["key"], 0.0) + rec["cost_usd"]
                STATE["requests"][rec["key"]] = STATE["requests"].get(rec["key"], 0) + 1
            except (KeyError, json.JSONDecodeError):
                continue
    # Replay response cache (requests flagged with "cache": true).
    if CACHE_FILE.exists():
        for line in CACHE_FILE.read_text(encoding="utf-8").splitlines():
            try:
                rec = json.loads(line)
                STATE["cache"][rec["k"]] = rec["response"]
            except (KeyError, json.JSONDecodeError):
                continue
    log(f"cache: {len(STATE['cache'])} entries loaded")
    log(f"{len(STATE['keys'])} keys loaded, spend replayed from usage.jsonl")


def pick_key():
    """Round-robin across keys still under budget. Returns key or None."""
    with STATE["lock"]:
        n = len(STATE["keys"])
        for _ in range(n):
            key = STATE["keys"][STATE["next"] % n]
            STATE["next"] += 1
            if STATE["spend"].get(key, 0.0) < STATE["budget"]:
                return key
    return None


def record_usage(key, cost_usd):
    with STATE["lock"]:
        STATE["spend"][key] = STATE["spend"].get(key, 0.0) + cost_usd
        STATE["requests"][key] = STATE["requests"].get(key, 0) + 1
        spend = STATE["spend"][key]
    with USAGE_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps({"ts": time.time(), "key": key, "cost_usd": cost_usd}) + "\n")
    remaining = STATE["budget"] - spend
    log(f"{mask(key)}: +${cost_usd:.6f} (total ${spend:.4f}, ~${remaining:.2f} left)")
    if remaining <= 0:
        log(f"WARNING: {mask(key)} reached its budget cap — proxy will skip it")


def cache_key(model, upstream):
    return hashlib.sha256(
        json.dumps({"m": model, "u": upstream}, sort_keys=True).encode()
    ).hexdigest()


def cache_lookup(key):
    with STATE["lock"]:
        return STATE["cache"].get(key)


def cache_store(key, response):
    with STATE["lock"]:
        STATE["cache"][key] = response
        if len(STATE["cache"]) > CACHE_MAX_ENTRIES:
            for old_key in list(STATE["cache"])[: CACHE_MAX_ENTRIES // 2]:
                del STATE["cache"][old_key]
    with CACHE_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps({"k": key, "response": response}) + "\n")


def send_json(handler, status, payload):
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):  # quiet default request logging
        pass

    def do_GET(self):
        if self.path == "/health":
            send_json(self, 200, {"ok": True, "model": DEFAULT_MODEL})
        elif self.path == "/status":
            with STATE["lock"]:
                keys = [
                    {
                        "key": mask(k),
                        "spent_usd": round(STATE["spend"].get(k, 0.0), 4),
                        "budget_usd": STATE["budget"],
                        "requests": STATE["requests"].get(k, 0),
                        "exhausted": STATE["spend"].get(k, 0.0) >= STATE["budget"],
                    }
                    for k in STATE["keys"]
                ]
            send_json(self, 200, {"model": DEFAULT_MODEL, "keys": keys,
                                  "cache_entries": len(STATE["cache"]),
                                  "cache_hits": STATE["cache_hits"]})
        else:
            send_json(self, 404, {"error": "unknown endpoint; try /health or /status"})

    def do_POST(self):
        if self.path != "/v1/chat/completions":
            send_json(self, 404, {"error": "unknown endpoint; POST /v1/chat/completions"})
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, json.JSONDecodeError):
            send_json(self, 400, {"error": "invalid JSON body"})
            return

        if body.get("stream"):
            send_json(self, 400, {"error": "streaming not supported; send stream=false"})
            return

        # Default to the cheap Mistral; only allow other mistralai/* models,
        # never let a client accidentally burn budget on a flagship model.
        model = body.get("model") or DEFAULT_MODEL
        if not model.startswith("mistralai/"):
            send_json(self, 400, {"error": f"model '{model}' blocked; only mistralai/* is allowed"})
            return

        or_key = pick_key()  # OpenRouter key — never clobber with the cache key
        if or_key is None:
            send_json(self, 429, {"error": "all key budgets exhausted — check /status and add keys to keys.json"})
            return

        upstream = {
            "model": model,
            "messages": body.get("messages", []),
        }
        for opt in ("max_tokens", "temperature", "top_p", "response_format"):
            if opt in body:
                upstream[opt] = body[opt]

        want_cache = bool(body.get("cache"))
        ckey = cache_key(model, upstream) if want_cache else None
        if ckey is not None:
            hit = cache_lookup(ckey)
            if hit is not None:
                with STATE["lock"]:
                    STATE["cache_hits"] += 1
                log(f"cache hit ({STATE['cache_hits']} total)")
                send_json(self, 200, hit)
                return

        req = urllib.request.Request(
            OPENROUTER_URL,
            data=json.dumps(upstream).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {or_key}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://github.com/LPuehringerStudent/KI-Hackathon-2026",
                "X-Title": "KI-Hackathon-2026 mistral-proxy",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", errors="replace")
            log(f"OpenRouter error {e.code} for {mask(or_key)}: {detail[:300]}")
            if e.code in (401, 403):
                with STATE["lock"]:
                    STATE["spend"][or_key] = STATE["budget"]
                log(f"disabling {mask(or_key)} — check that the key was pasted correctly")
            send_json(self, e.code, {"error": f"OpenRouter returned {e.code}", "detail": detail})
            return
        except urllib.error.URLError as e:
            send_json(self, 502, {"error": f"cannot reach OpenRouter: {e.reason}"})
            return

        usage = data.get("usage") or {}
        cost = ((usage.get("prompt_tokens", 0) * 0.0000015)
                + (usage.get("completion_tokens", 0) * 0.0000075))
        record_usage(or_key, cost)
        if want_cache:
            cache_store(ckey, data)
        send_json(self, 200, data)


def main():
    parser = argparse.ArgumentParser(description="Pool OpenRouter keys for cheap Mistral tasks")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()
    load_state()
    server = ThreadingHTTPServer((HOST, args.port), Handler)
    log(f"listening on http://{HOST}:{args.port} — model {DEFAULT_MODEL}")
    log(f"agents: point an OpenAI-compatible client at http://{HOST}:{args.port}/v1 (any dummy API key)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("shutting down")


if __name__ == "__main__":
    main()
