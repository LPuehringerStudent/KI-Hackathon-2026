import argparse
import json
from pathlib import Path
import urllib.error
import urllib.request


def generate(endpoint):
    with urllib.request.urlopen(endpoint + "/health", timeout=5) as response:
        if not json.load(response).get("ok"):
            raise RuntimeError("Proxy health check failed")
    result = {}
    for kind in ("tree", "street", "venue", "fountain", "toilet"):
        prompt = f"Schreibe genau vier unterschiedliche kurze deutsche Ich-Aussagen fuer eine {kind}-Persona in einem Linzer Festivalspiel. Ernsthaft, leicht poetisch, pro Aussage hoechstens zwei Saetze. Keine erfundenen Namen, Zahlen, Altersangaben, Betriebszustaende oder Entscheidungen. Frage nach dem Anliegen der Stadtplanung. Antworte nur mit einem JSON-Array aus vier Strings."
        request = urllib.request.Request(endpoint + "/v1/chat/completions", data=json.dumps({"messages": [{"role": "user", "content": prompt}], "max_tokens": 500}).encode(), headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=30) as response:
            lines = json.loads(json.load(response)["choices"][0]["message"]["content"])
        if not isinstance(lines, list) or len(lines) != 4 or any(not isinstance(line, str) or not line.strip() or len(line) > 600 or "[[" in line for line in lines):
            raise ValueError(f"Invalid fallback output for {kind}")
        result[kind] = lines
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", default="http://127.0.0.1:8377")
    args = parser.parse_args()
    try:
        voices = generate(args.endpoint)
    except urllib.error.HTTPError as error:
        if error.code == 429:
            raise SystemExit("Proxy budgets exhausted. Check /status; no retry.") from error
        if error.code in (401, 403):
            raise SystemExit("Proxy key authentication failed; check local key setup.") from error
        raise SystemExit(f"Proxy returned HTTP {error.code}; existing voices unchanged.") from error
    except (OSError, ValueError, KeyError, IndexError, RuntimeError) as error:
        raise SystemExit(f"Generation failed; existing voices unchanged: {error}") from error
    target = Path(__file__).resolve().parents[1] / "game/godot/data/fallback_voices.json"
    target.write_text(json.dumps(voices, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
