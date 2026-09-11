# KI-Hackathon 2026

Project by Team Arbeitszeitbetrug for the KI-Hackathon at the Grand Garage, Tabakfabrik Linz — 2026-09-11.

## About

<!-- One or two sentences: what does this project do? -->

## Team

| Name | GitHub | Role |
|------|--------|------|
|Laurenz  |LPuehringerStudent|      |
|Ayan|ayan2310|      |
|David|David-Fruehwirth|      |

## Quick start

<!-- How to set up and run the project. Fill in once the stack is decided. -->

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
