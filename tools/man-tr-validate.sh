#!/usr/bin/env sh
#
# Copyright (c) 2026 FreeBSD Russian Documentation Project
#
# SPDX-License-Identifier: BSD-2-Clause
#
# man-tr-validate.sh -- validate syntax of translated man pages.
#
# Recursively walks the translation directory, runs "mandoc -T lint"
# on every regular file, and writes the results to an output file.
#
# Files are classified into three categories by mandoc exit status:
#   clean     -- mandoc exited with status 0 (no diagnostics)
#   warnings  -- mandoc exited with status 1 (warnings only)
#   errors    -- mandoc exited with status 2 (errors present)
#
# Output format: tab-separated fields, one line per diagnostic:
#
#   file<TAB>level<TAB>line<TAB>column<TAB>message
#
# Usage:
#   man-tr-validate.sh [-q] [-f] [-v] <tr-dir> <out-file>
#
# Options:
#   -q   Quiet: print nothing on success.
#   -f   Force: overwrite the output file if it already exists.
#   -v   Verbose: print each file being checked.
#
# Exit status:
#   0   all files clean
#   1   usage error, missing input, or output file already exists
#   2   one or more files have warnings or errors
#

set -u

usage() {
    cat <<EOF
Usage: $0 [-q] [-f] [-v] <tr-dir> <out-file>

Options:
  -q   Quiet: print nothing on success.
  -f   Force: overwrite the output file if it already exists.
  -v   Verbose: print each file being checked.
EOF
    exit 1
}

quiet=0
force=0
verbose=0

while [ $# -gt 0 ]; do
    case "$1" in
        -q) quiet=1; shift ;;
        -f) force=1; shift ;;
        -v) verbose=1; shift ;;
        --) shift; break ;;
        -*) echo "$0: unknown option: $1" >&2; usage ;;
        *) break ;;
    esac
done

if [ $# -ne 2 ]; then
    usage
fi

tr_dir=$1
out_file=$2

if [ ! -d "$tr_dir" ]; then
    echo "$0: translations directory does not exist: $tr_dir" >&2
    exit 1
fi

if [ -e "$out_file" ] && [ "$force" -eq 0 ]; then
    echo "$0: output file already exists: $out_file" >&2
    echo "$0: use -f to overwrite" >&2
    exit 1
fi

if ! command -v mandoc >/dev/null 2>&1; then
    echo "$0: mandoc not found in PATH" >&2
    echo "$0: install it with 'brew install mandoc' on macOS" >&2
    exit 1
fi

tmp_list=$(mktemp) || exit 1
tmp_out=$(mktemp) || exit 1
tmp_counts=$(mktemp) || exit 1
trap 'rm -f "$tmp_list" "$tmp_out" "$tmp_counts"' EXIT HUP INT TERM

find "$tr_dir" -type f | LC_ALL=C sort > "$tmp_list"

: > "$tmp_counts"

while IFS= read -r file; do
    [ "$verbose" -eq 1 ] && echo "checking: $file" >&2

    output=$(mandoc -T lint "$file" 2>&1)
    status=$?

    case "$status" in
        0)
            printf 'clean\n' >> "$tmp_counts"
            continue
            ;;
        1)
            printf 'warnings\n' >> "$tmp_counts"
            ;;
        2)
            printf 'errors\n' >> "$tmp_counts"
            ;;
        *)
            printf 'unknown\n' >> "$tmp_counts"
            ;;
    esac

    # Record diagnostics for non-clean files.
    printf '%s\n' "$output" | while IFS= read -r line; do
        [ -z "$line" ] && continue

        level=$(printf '%s\n' "$line" | sed -n 's/^[^:]*: [^:]*:[0-9]*:[0-9]*: \([A-Z]*\):.*$/\1/p')
        lineno=$(printf '%s\n' "$line" | sed -n 's/^[^:]*: [^:]*:\([0-9]*\):[0-9]*:.*$/\1/p')
        col=$(printf '%s\n' "$line" | sed -n 's/^[^:]*: [^:]*:[0-9]*:\([0-9]*\):.*$/\1/p')
        msg=$(printf '%s\n' "$line" | sed -n 's/^[^:]*: [^:]*:[0-9]*:[0-9]*: [A-Z]*: \(.*\)$/\1/p')

        printf '%s\t%s\t%s\t%s\t%s\n' "$file" "$level" "$lineno" "$col" "$msg" >> "$tmp_out"
    done
done < "$tmp_list"

mv "$tmp_out" "$out_file"

clean_count=$(grep -c '^clean$' "$tmp_counts" || true)
warn_count=$(grep -c '^warnings$' "$tmp_counts" || true)
err_count=$(grep -c '^errors$' "$tmp_counts" || true)
unknown_count=$(grep -c '^unknown$' "$tmp_counts" || true)

total=$((clean_count + warn_count + err_count + unknown_count))

if [ "$quiet" -eq 0 ]; then
    echo "Translations:       $tr_dir"
    echo "Output:             $out_file"
    echo "Files total:        $total"
    echo "Clean (no issues):  $clean_count"
    echo "Warnings only:      $warn_count"
    echo "Errors:             $err_count"
    if [ "$unknown_count" -gt 0 ]; then
        echo "Unknown status:     $unknown_count"
    fi
fi

if [ "$warn_count" -gt 0 ] || [ "$err_count" -gt 0 ] || [ "$unknown_count" -gt 0 ]; then
    exit 2
fi

exit 0
