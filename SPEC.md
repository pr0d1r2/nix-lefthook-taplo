# SPEC — nix-lefthook-taplo

## §G Goal

Lefthook-compatible taplo wrapper for TOML linting. Filter `.toml` files
from the staged/pushed argument list and run `taplo check` on them, blocking
the commit/push when any file fails to parse. Packaged as a Nix flake.
Opensource-safe: zero credentials, zero local paths, zero private refs.

## §C Constraints

- C1: Pure bash — taplo is the only runtime tool, no Python/Ruby/etc deps
- C2: Nix flake — `writeShellApplication` pkg, plain `mkShell` devShells
- C3: MIT license
- C4: Multi-platform: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux`
- C5: Detached from parent project — no credential leaks, no hardcoded local paths, no private repo refs
- C6: All config via env vars — no config files beyond baseline
- C7: Exit non-zero on TOML parse failure — hard enforcement, blocks commit/push
- C8: 2-space indentation, LF endings, final newline, no trailing whitespace (`.editorconfig` enforced)
- C9: Flattened flake — `flake = false` `-src` inputs for every wrapper the remotes invoke, plus `nixpkgs-lock`; no `flake = true` inputs, so no transitive dependency-tree explosion

## §I Interfaces

- I.cli: `lefthook-taplo FILE...` — main binary; filters `.toml` files, runs `taplo check`, exit 0 on pass, exit non-zero on parse failure
- I.env: `LEFTHOOK_TAPLO_TIMEOUT` (seconds, default `30`) — wraps the hook invocation in `timeout` from `lefthook.yml` / `lefthook-remote.yml`
- I.remote: `lefthook-remote.yml` — consumers add this repo as a lefthook remote; `pre-commit` runs `lefthook-taplo {staged_files}`, `pre-push` runs `lefthook-taplo {push_files}`, both globbed to `*.toml`
- I.flake: `packages.${system}.default` — the `lefthook-taplo` Nix pkg output
- I.devshell: `devShells.${system}.default` + `.#ci` — dev/CI shells via plain `mkShell`; both carry the pkg, bats-with-libs, taplo, lefthook, git, nix, parallel, coreutils, and the full wrapper suite
- I.ci: `.github/workflows/ci.yml` — linux + macos via `nix-lefthook-ci-action` (nix build + lefthook pre-commit + pre-push)

## §V Invariants

- V1: No arguments → immediate exit 0 (nothing staged matches `*.toml`)
- V2: Only `*.toml` files are checked — every other extension is filtered out of the argument list
- V3: Non-existent paths are skipped silently (`[ -f "$f" ]` guard) — no crash on deleted/renamed files
- V4: After filtering, an empty file list → exit 0 (no taplo invocation)
- V5: `taplo check` is `exec`'d on the surviving file list — its exit code is the hook's exit code, so invalid TOML blocks the commit/push
- V6: Hook script is sourced by `writeShellApplication` — no shebang, no `set` lines of its own (the wrapper supplies `set -euo pipefail`)
- V7: `LEFTHOOK_TAPLO_TIMEOUT` bounds runtime (default 30s) — set in both `lefthook.yml` and `lefthook-remote.yml`
- V8: `default` devShell `shellHook` expands `dev.sh` with `@BATS_LIB_PATH@` substituted, sets `BATS_LIB_PATH`, and runs `lefthook install` when `.git/hooks/pre-commit` is absent
- V9: `ci` devShell exports `BATS_LIB_PATH` directly and omits the install hook
- V10: No credentials, secrets, tokens, API keys, or private paths in any tracked file
- V11: No hardcoded local filesystem paths (enforced by `nix-lefthook-git-no-local-paths` hook)
- V12: `flake.lock` pins `nixpkgs` via `nixpkgs-lock`; all wrapper inputs are `flake = false` `-src` leaves, keeping the lock small
- V13: `config/lefthook/file_size_limits.yml` raises the `nix` limit to 10240 bytes to accommodate the inline wrapper definitions in `flake.nix`
- V14: CI runs both pre-commit and pre-push on linux + macos
- V15: All linters pass: nixfmt, shellcheck, shfmt, statix, deadnix, nix-no-embedded-shell, bats-parse, bats-unit, yamllint, typos, trailing-whitespace, missing-final-newline, git-conflict-markers, editorconfig-checker, git-no-local-paths, file-size-check, nix-flake-check
- V16: `packages.${system}.default` set and `devShells` (`ci` + `default`) are the only flake outputs — stable surface across the supported systems

## §T Tasks

| id | status | task | cites |
| --- | --- | --- | --- |
| T1 | x | core wrapper script: filter `*.toml`, skip missing, exec `taplo check` | V1,V2,V3,V4,V5,I.cli |
| T2 | x | sourced-by-writeShellApplication shape (no shebang/set) | V6,C1 |
| T3 | x | timeout env var wiring in lefthook configs | V7,I.env |
| T4 | x | Nix flake pkg (`writeShellApplication`, runtimeInputs = taplo) | C2,I.flake |
| T5 | x | flattened inputs: nixpkgs-lock + 15 `flake = false` wrapper leaves | C9,V12 |
| T6 | x | devShells `ci` + `default` via plain mkShell with full wrapper suite | C2,I.devshell,V8,V9 |
| T7 | x | lefthook-remote.yml for consumers (pre-commit + pre-push) | I.remote |
| T8 | x | dev.sh — BATS_LIB_PATH + auto-install lefthook | V8 |
| T9 | x | unit tests: lefthook-taplo.bats (valid/invalid/mixed/missing/empty) | V1-V5 |
| T10 | x | unit tests: dev.bats (placeholder, install, skip-install) | V8 |
| T11 | x | GitHub Actions CI: linux + macos via nix-lefthook-ci-action | V14,I.ci |
| T13 | x | linter suite via lefthook remotes | V15 |
| T14 | x | file_size_limits.yml: nix limit 10240 for inline wrappers | V13 |
| T15 | x | opensource audit: no credentials/local-paths/private-refs | V10,V11,C5 |
| T16 | x | .gitignore: result, result-*, .direnv | V10,C5 |
