# KI-Hackathon 2026

Project by Team Arbeitszeitbetrug for the KI-Hackathon at the Grand Garage, Tabakfabrik Linz — 2026-09-11.

## About

Godot desktop game: lead Linz through three festival days, negotiate with city
entities, and balance attendance, money, and happiness using local open data.

## Team

| Name | GitHub | Role |
|------|--------|------|
|Laurenz  |LPuehringerStudent|      |
|Ayan|ayan2310|      |
|David|David-Fruehwirth|      |

## Quick start

Requires Godot 4.7.2 (standard GDScript build). Open `game/godot/project.godot`
and run the main scene, or run from the repository root:

```sh
godot --path game/godot
```

The map, scoring, decisions, and canned dialogue work offline. For live voices,
configure the local keys as described in [mistral-proxy/README.md](mistral-proxy/README.md),
then start `python3 mistral-proxy/server.py` in a second terminal. The game uses
only `http://127.0.0.1:8377/v1/chat/completions`, with an eight-second timeout.

Choose entities on the map, negotiate or use their decision buttons, then advance
through three days. `Abschluss` shows the final verdict; `Neues Festival` restarts.

### Check and export

```sh
godot --headless --path game/godot --editor --import --quit
godot --headless --path game/godot --quit
godot --headless --path game/godot -s res://tests/run_tests.gd
godot --headless --path game/godot -s res://tests/run_data_tests.gd
godot --headless --path game/godot -s res://tests/run_panel_tests.gd
godot --headless --path game/godot -s res://tests/run_integration_tests.gd
python3 tools/check_proxy_client.py /path/to/godot
```

Install matching export templates in Godot. Create `game/godot/build/`, then:

```sh
godot --headless --path game/godot --export-release Linux build/buergermeister.x86_64
chmod +x game/godot/build/buergermeister.x86_64
./game/godot/build/buergermeister.x86_64
```

The Linux executable embeds its data pack. No Python or proxy is required for
offline play. Keep the map import mode at **Keep File**: the map loader reads the
original PNG. Tests are excluded from the export.

Implementation details, dependency branches, verification results, and remaining
demo checks are in [docs/track-c-handoff.md](docs/track-c-handoff.md).

## Data

Ready-to-use snapshots live in [`data/`](data/README.md): the official
[Festival 2026 program dataset](https://ars.electronica.art/negotiatinghumanity/hackathondata/)
(JSON, bilingual, join via `canonical_id`) and 12 prepared
[City of Linz open datasets](https://data.linz.gv.at) (CSV/GeoJSON, WGS84).
Read [data/README.md](data/README.md) for schemas, caveats, and refresh commands.

## Cheap-task offload

Easy tasks (summaries, boilerplate, small transforms) can go through the local
Mistral proxy to save the main model's quota — see [mistral-proxy/README.md](mistral-proxy/README.md).
It pools the team's 3 OpenRouter keys ($20 each) and exposes an OpenAI-compatible
endpoint on `127.0.0.1:8377`.

## Contributing

We work with short-lived feature branches and pull requests. See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow.

## License

[MIT](LICENSE)
