# AGENTS.md — Instructions for coding agents on this team

## Cheap-task offload via the local Mistral proxy

This team has 3 OpenRouter keys (Mistral Medium 3.5, $20 budget each) pooled in a
local proxy. **Use it for easy, self-contained tasks to conserve the main model's
quota.** The proxy is NOT a replacement for the main agent — it is a weaker,
cheaper helper for mechanical work.

### Before using

1. Check the proxy is running: `curl -s http://127.0.0.1:8377/health`
2. If not, start it: `python3 mistral-proxy/server.py` (run_in_background if long-lived) and re-check `/health`.
3. If `/health` fails after starting, `mistral-proxy/keys.json` is missing — tell the
   human (setup: `mistral-proxy/README.md`).

### Good tasks for the proxy (single-turn, self-contained)

- Summarizing text, logs, or diffs ("summarize this error in one line")
- Drafting commit messages, PR descriptions, or short doc snippets
- Explaining a small code fragment or a stack trace
- Mechanical rewrites: renaming, reformatting, translating short prose
- Simple data transforms on SMALL inputs (a few KB, not whole files/datasets)

### Keep on the main model (do NOT offload)

- Architecture/design decisions, planning, multi-step reasoning
- Anything touching multiple files or subtle logic
- Debugging non-obvious bugs, security-sensitive code, credentials handling
- Large inputs — if the prompt is bigger than ~50 KB, it's not a proxy task

### How to call it

Bash (short prompts):

```bash
curl -s http://127.0.0.1:8377/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"YOUR PROMPT"}],"max_tokens":500}' \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['choices'][0]['message']['content'])"
```

Pipe file content safely instead of shell-escaping it:

```bash
python3 -c "
import json, sys, urllib.request
prompt = 'Summarize this diff in 3 bullet points:\n' + sys.stdin.read()
req = urllib.request.Request('http://127.0.0.1:8377/v1/chat/completions',
    data=json.dumps({'messages': [{'role': 'user', 'content': prompt}], 'max_tokens': 500}).encode(),
    headers={'Content-Type': 'application/json'})
print(json.loads(urllib.request.urlopen(req).read())['choices'][0]['message']['content'])
" < /path/to/file
```

Rules:

- Always set `max_tokens` (default 500; 100 is enough for one-liners). Output tokens cost ~5x input.
- No `stream` — plain JSON response only.
- Do not pass `model` unless needed; the proxy defaults to `mistralai/mistral-medium-3-5` and blocks non-Mistral models anyway.
- Never put secrets, API keys, or personal data in prompts.
- If you get `429` ("all key budgets exhausted"), check `curl -s http://127.0.0.1:8377/status` and tell the human — do not retry in a loop.
- If you get `401`/`403` on the first call, a key is likely pasted wrong — tell the human.
- On any other failure, fall back to doing the task yourself instead of retrying repeatedly.

### Cost awareness

Every request is logged with its cost. `/status` shows spent-vs-budget per key.
When in doubt about whether a task is "easy enough", do it yourself — a few main-model
tokens are cheaper than a wasted $20 key.
