# Contributing to Stadttopia

Thanks for your interest! Stadttopia was built in 48 hours at the Ars Electronica
2026 AI hackathon and is now maintained by [Laurenz](https://github.com/LPuehringerStudent).
External contributions are welcome — bug fixes, data-pipeline improvements, balance
tuning, new city profiles, and documentation all count.

## Before you start

- **Issues first for anything non-trivial.** Open an issue describing the change
  so we can agree on direction before you write code. Small fixes and docs
  corrections can go straight to a PR.
- The `AGENTS.md` track table documents how the original hackathon team split the
  work across three human–AI pairs. It is **historical context, not a rule** —
  you may touch any part of the codebase.

## Development setup

1. Install **Godot 4.7.2** (standard build) and Python 3.10+.
2. Clone and import once — this step is **required** after every pull:

   ```bash
   godot --headless --path game/godot --import
   ```

   Running the game without importing first uses stale cached assets
   (old maps, missing sprites).

3. Play: `godot --path game/godot`. Live AI voices need the local proxy
   (see `mistral-proxy/README.md`); everything else works offline.

## Pull requests

- Branch off `main`, one logical change per PR, descriptive title and body
  (what/why/how tested — the PR template guides you).
- **All headless suites must pass.** Run at minimum:

  ```bash
  godot --headless --path game/godot -s res://tests/run_tests.gd
  godot --headless --path game/godot -s res://tests/run_integration_tests.gd
  ```

  The full set (data, panels, menu, style, proxy client) lives in the README.
  New behavior needs new tests in `game/godot/tests/` — follow the existing
  suite files.
- Balance changes (constants in `game_state.gd`) are welcome but must keep
  `test_balance_real_data.gd` green and list every changed constant in the PR body.
- Laurenz reviews and merges. Docs-only PRs may be merged by their author once
  CI-less checks (a fresh `--import` and the menu suite) pass.

## Hard rules

- **Never commit secrets.** API keys live in untracked, gitignored files
  (`mistral-proxy/keys.json`). If you add an integration that needs credentials,
  document the expected file — never the values.
- Don't commit generated build output (`game/godot/build/`) or the Godot import
  cache (`.godot/`) — both are gitignored; keep it that way.
- Regenerated data (`game/godot/data/*.json`) is only committed via the
  extraction/render tools, never hand-edited — fix the tool, not the output.

## Data & licensing

Game data comes from the City of Linz (CC BY 4.0), OpenStreetMap (ODbL), the
Land Oberösterreich air-quality API (CC BY 4.0), and the Ars Electronica festival
dataset. Keep attribution intact when adding datasets. See the README for details.

By contributing you agree your work is licensed under the project's [MIT license](LICENSE).
