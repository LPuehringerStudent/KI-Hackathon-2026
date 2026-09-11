# Contributing

Workflow for our 3-person team. The goal: nobody blocks anyone, and `main` always works.

## Branching

- `main` is always in a working state. Never commit directly to `main`.
- Create short-lived branches off `main`: `feature/<short-desc>`, `fix/<short-desc>`, `docs/<short-desc>`
  (e.g. `feature/api-endpoint`, `fix/login-crash`).
- Keep branches small — one feature or fix per branch, ideally mergeable within a few hours.
- Delete branches after merging.

## Commits

- Write commit messages in the imperative: "add endpoint", "fix crash on empty input".
- One logical change per commit; don't mix unrelated changes.

## Pull requests

- Open a PR as soon as the branch is roughly ready — draft PRs are fine for early feedback.
- Keep PRs small and reviewable (a few hundred lines max).
- Anyone can review; **at least one teammate must approve before merging** (use GitHub's review).
- PR author merges their own PR after approval (no long handoffs).
- CI / tests (once they exist) must be green before merging.

## Staying in sync

- Pull `main` frequently (`git pull --rebase origin main` while on your branch) to catch conflicts early.
- **Never force-push to `main` or to someone else's branch.** Force-pushing your own feature branch is OK if you coordinate in chat.
- If you hit a merge conflict you can't resolve, ask in the team chat — don't guess.

## General

- Discuss big design decisions before building them.
- Update this file if the team agrees on new rules.
