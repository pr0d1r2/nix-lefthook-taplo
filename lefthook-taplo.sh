# shellcheck shell=bash
# Lefthook-compatible taplo wrapper.
# NOTE: sourced by writeShellApplication — no shebang or set needed.

if [ $# -eq 0 ]; then
    exit 0
fi

files=()
for f in "$@"; do
    [ -f "$f" ] || continue
    case "$f" in
        *.toml) files+=("$f") ;;
    esac
done

if [ ${#files[@]} -eq 0 ]; then
    exit 0
fi

exec taplo check "${files[@]}"
