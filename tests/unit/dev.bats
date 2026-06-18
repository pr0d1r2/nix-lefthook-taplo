#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031  # per-test subshell env exports are intentional

setup() {
    load "${BATS_LIB_PATH}/bats-support/load.bash"
    load "${BATS_LIB_PATH}/bats-assert/load.bash"

    TMPDIR="$(mktemp -d)"
    git init "$TMPDIR/repo" >/dev/null 2>&1
    mkdir -p "$TMPDIR/repo/.git/hooks"
    touch "$TMPDIR/repo/.git/hooks/pre-commit"

    sed -e 's|@BATS_LIB_PATH@|/test/lib|' -e 's|@MKSET@|mkSet|' dev.sh > "$TMPDIR/dev.sh"

    mkdir -p "$TMPDIR/bin"
    cat > "$TMPDIR/bin/lefthook" <<'SH'
#!/usr/bin/env bash
echo "lefthook $*" >> "$LEFTHOOK_LOG"
SH
    chmod +x "$TMPDIR/bin/lefthook"

    cat > "$TMPDIR/bin/mkSet" <<'SH'
#!/usr/bin/env bash
echo "mkSet $*" >> "$MKSET_LOG"
SH
    chmod +x "$TMPDIR/bin/mkSet"

    export PATH="$TMPDIR/bin:$PATH"
    export LEFTHOOK_LOG="$TMPDIR/log"
    export MKSET_LOG="$TMPDIR/mkset-log"
}

teardown() {
    rm -rf "$TMPDIR"
}

@test "sets BATS_LIB_PATH from placeholder" {
    cd "$TMPDIR/repo"
    run bash -c 'unset BATS_LIB_PATH; source "$1"; echo "$BATS_LIB_PATH"' -- "$TMPDIR/dev.sh"
    assert_success
    assert_output --partial "/test/lib/share/bats"
}

@test "runs lefthook install when hooks are missing" {
    cd "$TMPDIR/repo"
    rm "$TMPDIR/repo/.git/hooks/pre-commit"
    # shellcheck disable=SC1091
    source "$TMPDIR/dev.sh"
    assert [ -f "$LEFTHOOK_LOG" ]
    run cat "$LEFTHOOK_LOG"
    assert_output "lefthook install"
}

@test "skips lefthook install when hooks exist" {
    cd "$TMPDIR/repo"
    # shellcheck disable=SC1091
    source "$TMPDIR/dev.sh"
    assert [ ! -f "$LEFTHOOK_LOG" ]
}

@test "materializes set skills via mkSet" {
    cd "$TMPDIR/repo"
    # shellcheck disable=SC1091
    source "$TMPDIR/dev.sh"
    assert [ -f "$MKSET_LOG" ]
    run cat "$MKSET_LOG"
    assert_output "mkSet nix lefthook test"
}
