#!/usr/bin/env python3
"""Cache one air-quality reading for the game's Day-3 (Hitzetag) modifier.

Fetches the rolling 24 h JSON API of the Land Oberösterreich (CC BY 4.0) and
writes game/godot/data/airquality.json in the contract agreed with Track B:

    { "station": "…", "measured_at": "ISO-8601", "pm10": 23.0,
      "pm25": 12.0, "source": "…" }

The file is OPTIONAL: data_loader exposes it as data.airquality only when
present, and game_state treats a missing file as modifier 0.

Units: the API reports particulates in mg/m³ — converted to µg/m³ here,
which is what the modifier thresholds (PM10 ≤ 20 / ≥ 50) refer to.
"""

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "godot" / "data" / "airquality.json"

API = "https://www2.land-oberoesterreich.gv.at/imm/jaxrs/messwerte/json?stationcode={}"
# Stadtpark is next to OK Platz (festival core); the rest are fallbacks.
# S425 (Freinberg) has no particulate sensors and is intentionally absent.
STATIONS = [("S184", "Stadtpark"), ("S415", "24er-Turm"),
            ("S416", "Neue Welt"), ("S431", "Römerberg")]

UA = {"User-Agent": "KI-Hackathon-2026 airquality cache (CC BY 4.0 data)"}


def latest(records, component):
    best_t, best_v = None, None
    for r in records:
        if r.get("komponente") != component:
            continue
        try:
            t = int(r["zeitpunkt"])
            v = float(str(r["messwert"]).replace(",", "."))
        except (KeyError, ValueError):
            continue
        if best_t is None or t > best_t:
            best_t, best_v = t, v
    return best_t, best_v


def fetch_station(code):
    with urlopen(Request(API.format(code), headers=UA), timeout=30) as r:
        return json.loads(r.read().decode()).get("messwerte", [])


def main():
    for code, name in STATIONS:
        try:
            records = fetch_station(code)
        except Exception as e:
            print(f"{code} {name}: fetch failed ({e}) — trying next")
            continue
        t10, v10 = latest(records, "PM10kont")
        t25, v25 = latest(records, "PM25kont")
        if v10 is None or v25 is None:
            print(f"{code} {name}: no PM data — trying next")
            continue
        measured_ms = max(t for t in (t10, t25) if t is not None)
        payload = {
            "station": f"{code} {name}",
            "measured_at": datetime.fromtimestamp(measured_ms / 1000, tz=timezone.utc).isoformat(),
            # API unit mg/m³ -> µg/m³
            "pm10": round(v10 * 1000.0, 1),
            "pm25": round(v25 * 1000.0, 1),
            "source": f"Land Oberösterreich Umweltschutz, {API.format(code)} (CC BY 4.0)",
        }
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(payload, indent=1), encoding="utf-8")
        print(f"wrote {OUT}: {payload['station']} PM10={payload['pm10']} "
              f"PM25={payload['pm25']} at {payload['measured_at']}")
        return
    print("no station with PM data reachable — leaving any existing cache untouched")
    sys.exit(1)


if __name__ == "__main__":
    main()
