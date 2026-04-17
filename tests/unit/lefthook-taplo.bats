#!/usr/bin/env bats

setup() {
    load "$BATS_LIB_PATH/bats-support/load"
    load "$BATS_LIB_PATH/bats-assert/load"
    load "$BATS_LIB_PATH/bats-file/load"

    TEST_TEMP="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TEMP"
}

@test "exits 0 with no arguments" {
    run lefthook-taplo
    assert_success
}

@test "exits 0 when no .toml files in arguments" {
    touch "$TEST_TEMP/file.txt"
    run lefthook-taplo "$TEST_TEMP/file.txt"
    assert_success
}

@test "skips missing files silently" {
    run lefthook-taplo "/nonexistent/file.toml"
    assert_success
}

@test "accepts valid TOML file" {
    cat > "$TEST_TEMP/good.toml" << 'EOF'
[package]
name = "test"
version = "1.0.0"
EOF
    run lefthook-taplo "$TEST_TEMP/good.toml"
    assert_success
}

@test "detects invalid TOML" {
    cat > "$TEST_TEMP/bad.toml" << 'EOF'
[package
name = missing bracket
EOF
    run lefthook-taplo "$TEST_TEMP/bad.toml"
    assert_failure
}

@test "filters non-.toml files from mixed input" {
    cat > "$TEST_TEMP/good.toml" << 'EOF'
[package]
name = "test"
EOF
    touch "$TEST_TEMP/file.txt"
    run lefthook-taplo "$TEST_TEMP/good.toml" "$TEST_TEMP/file.txt"
    assert_success
}
