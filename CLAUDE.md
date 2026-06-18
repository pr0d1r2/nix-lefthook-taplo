# nix-lefthook-taplo

## Skills

Behavioral rules are materialized by `mkSet` (from the `set-and-setting`
flake input) into `.claude/skills/set/` and `.claude/rules/` on every
dev shell entry. They are gitignored and regenerated from the pinned
`flake.lock` rev — the lock is the single source of truth.

Categories: `nix lefthook test` plus core (`generic git`). Wired in
`dev.sh` (`@MKSET@ nix lefthook test`, substituted in `flake.nix`).

To change a rule, edit it in `set-and-setting` and bump this repo's
`flake.lock` — do not edit `.claude/` (it is overwritten). Adding a new
category: extend the `mkSet` args in `dev.sh`.

## Repo layout

- Dev shell hook script: `dev.sh` (root), placeholders substituted in
  `flake.nix` via `replaceStrings`.
- Tests mirror root scripts: `<name>.sh` → `tests/unit/<name>.bats`.
- `.envrc` is `use flake`; reload after changing `flake.nix`/`flake.lock`.
