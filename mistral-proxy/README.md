# Mistral Proxy — cheap-task offload for your agents

Pools the team's 3 OpenRouter keys (Mistral Medium 3.5, $20 budget each) behind a
local OpenAI-compatible endpoint. Agents send **easy tasks** here (summaries,
simple rewrites, boilerplate, small transforms) and save the main model's quota
for the hard work.

- Model: `mistralai/mistral-medium-3-5` (~$1.50/M input, ~$7.50/M output)
- Zero dependencies: Python 3 stdlib only
- Listens on `127.0.0.1:8377` (localhost only, no auth needed locally)

## Setup (one-time, per team)

1. Each teammate redeems their personal code → gets an OpenRouter key:
   <https://hackathon.ars.electronica.art/redeem>
2. One teammate collects all 3 keys and shares them **offline** (chat/USB/hotspot —
   never via git).
3. On **each laptop**: `cp keys.json.example keys.json` and paste the 3 keys.

`keys.json` and `usage.jsonl` are gitignored — never commit them.

## Run

```bash
python3 mistral-proxy/server.py            # or: --port 8377
curl http://127.0.0.1:8377/health          # {"ok": true, ...}
curl http://127.0.0.1:8377/status          # per-key spend vs budget
```

## Use from any agent

Point any OpenAI-compatible client at `http://127.0.0.1:8377/v1` with any dummy
API key, model `mistralai/mistral-medium-3-5`. Examples:

```bash
# Quick check from Bash / a Task call
curl -s http://127.0.0.1:8377/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Summarize this error in one line: ..."}]}' \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['choices'][0]['message']['content'])"
```

```python
# From Python (stdlib only)
import json, urllib.request
req = urllib.request.Request(
    "http://127.0.0.1:8377/v1/chat/completions",
    data=json.dumps({"messages": [{"role": "user", "content": "..."}]}).encode(),
    headers={"Content-Type": "application/json"},
)
print(json.loads(urllib.request.urlopen(req).read())["choices"][0]["message"]["content"])
```

### Response cache (game dialogue)

Requests with `"cache": true` are served from a persistent disk cache
(`cache.jsonl`) when the exact same request (model + messages + options) was
seen before — repeat dialogue is instant, free, and demo-consistent. The game
client sets this automatically. Cache stats appear in `GET /status`
(`cache_entries`, `cache_hits`); hits cost nothing and are not logged as usage.

Rules the proxy enforces:

- Only `mistralai/*` models are allowed (so nobody burns budget on a flagship model by accident)
- Requests round-robin across keys that still have budget; a key near its $20 limit is skipped
- Spend is logged per request to `usage.jsonl` and survives restarts; watch it via `GET /status`
- No streaming — send `stream=false` (or omit `stream`)

## Budget tips

- $60 total is plenty, but output tokens cost 5x input — cap `max_tokens` for simple tasks (e.g. 500).
- If a key runs dry, redistribute: lower `budget_usd` in `keys.json`, or the key's owner regenerates it.
- At the end of the hackathon, `usage.jsonl` shows exactly what each key spent.
