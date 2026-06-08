# Flatten SPEC — nix-lefthook-taplo

## Goal
Remove the `nix-dev-shell-agentic` flake input (and its transitive
explosion) from `flake.nix`, preserving the `lefthook-taplo` package output
and keeping CI (`nix develop .#ci` + remote lefthook hooks) and bats green.

## Before
- flake.lock: 59 nodes.
- Inputs: nixpkgs-lock, nixpkgs(follows), nix-dev-shell-agentic(flake).
- Outputs: packages.<sys>.default = lefthook-taplo; devShells ci/default via
  nix-dev-shell-agentic.lib.mkShells.

## Consumption of the agentic devShell here
- `.envrc` = `use flake` → devShells.<sys>.default.
- CI enters `nix develop .#ci` and runs lefthook install / pre-commit /
  pre-push --all-files.
- lefthook.yml `remotes:` invoke wrapper binaries that must be on PATH in
  the ci shell: lefthook-{nixfmt,shellcheck,shfmt,deadnix,bats-unit,yamllint,
  typos,trailing-whitespace,missing-final-newline,git-conflict-markers,
  editorconfig-checker,git-no-local-paths,file-size-check}; bare `bats`
  (bats-parse), bare `nix flake check` (nix-flake-check); plus lefthook, git,
  coreutils, parallel, taplo.
- bats unit tests need BATS_LIB_PATH + lefthook-taplo on PATH.

## Changes
### Inputs
Remove nix-dev-shell-agentic. Add `flake = false` `-src` inputs for each
sibling wrapper the remotes invoke (15 leaves: the statix template set plus
statix and nix-no-embedded-shell, which taplo consumes as remotes). Result
inputs: nixpkgs-lock, nixpkgs(follows), + 15 flake=false leaves. No flake
input -> no dep-tree explosion.

### packages (UNCHANGED logic)
packages.<sys>.default = writeShellApplication { name="lefthook-taplo";
runtimeInputs=[pkgs.taplo]; text=readFile ./lefthook-taplo.sh; }.

### devShells (plain mkShell)
lefthookWrappersFor helper (copied from proven statix template:
bats-unit + file-size-check get special multi-input handling, rest via `wrap`).
batsWithLibsFor helper. ciCommon = [self pkg, batsWithLibs, bats, coreutils,
git, lefthook, nix, parallel, taplo] ++ wrappers.
- ci = mkShell { packages = ciCommon; BATS_LIB_PATH = "${batsWithLibs}/share/bats"; }
- default = mkShell { packages = ciCommon; shellHook = dev.sh expanded; }

### Side changes required to land a flattened flake green
1. config/lefthook/file_size_limits.yml: nix 4096 -> 10240. The flattened
  flake.nix has 15 inline wrappers and exceeds 4096 bytes; the proven
  statix template repo uses nix:10240 for the same reason. Pure config.
2. lefthook-taplo.sh: reformat 4-space -> 2-space because the upstream shfmt
  remote default (`-i 2` on main) requires it. Whitespace-only; behavior
  identical.

## Validation gate (all must pass)
1. nix flake check — PASS.
2. nix flake show — packages.<sys>.default = lefthook-taplo; devShells ci+default. UNCHANGED set.
3. nix build .#default + smoke (no-arg → 0, non-toml → 0, bad toml → 1).
4. bats tests/unit/ inside nix develop .#ci — PASS.
5. lefthook run pre-commit --all-files inside .#ci — PASS.
6. lock nodes << 59.

## Then
Branch flatten-drop-agentic, commit, push, DRAFT PR.
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
