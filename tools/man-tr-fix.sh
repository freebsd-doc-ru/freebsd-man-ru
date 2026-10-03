#!/usr/bin/env sh
#
# Copyright (c) 2026 FreeBSD Russian Documentation Project
# Copyright (c) 2026 Vladlen Popolitov
#
# SPDX-License-Identifier: BSD-2-Clause
#
# man-tr-fix.sh -- update the fourth field of a metadata file.
#
# For each line of the metadata file, checks whether a translation file
# exists in the translation store and adjusts the fourth field
# (last_existed_orig_hash) accordingly.
#
# The metadata file has five fields per line, separated by "|":
#
#   src_path|target_path|orig_hash|last_existed_orig_hash|git_commit_hash
#
# Lines starting with "#" are treated as comments and passed through
# unchanged.
#
# For each non-comment line, the following rules are applied:
#
#   1. If the translation file for orig_hash exists:
#          last_existed_orig_hash := orig_hash
#   2. Otherwise, if the translation file for the current
#      last_existed_orig_hash exists:
#          last_existed_orig_hash is left unchanged
#   3. Otherwise (neither file exists):
#          last_existed_orig_hash := orig_hash
#
# All other fields are left untouched.  Order of lines is preserved.
#
# Usage:
#   man-tr-fix.sh [-q] [-v] [-n] <meta-file> <translations-dir>
#
# Options:
#   -q   Quiet: print nothing on success.
#   -v   Verbose: print each changed line.
#   -n   Dry run: do not modify the metadata file.
#
# Exit status:
#   0   success
#   1   usage error, missing meta file, or missing translations directory
#   2   one or more lines could not be processed
#

set -u

usage() {
    cat <<EOF
Usage: $0 [-q] [-v] [-n] <meta-file> <translations-dir>

Options:
  -q   Quiet: print nothing on success.
  -v   Verbose: print each changed line.
  -n   Dry run: do not modify the metadata file.
EOF
    exit 1
}

quiet=0
verbose=0
dry_run=0

while [ $# -gt 0 ]; do
    case "$1" in
        -q)
            quiet=1
            shift
            ;;
        -v)
            verbose=1
            shift
            ;;
        -n)
            dry_run=1
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "$0: unknown option: $1" >&2
            usage
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -ne 2 ]; then
    usage
fi

meta_file=$1
tr_dir=$2

if [ ! -f "$meta_file" ]; then
    echo "$0: meta file does not exist: $meta_file" >&2
    exit 1
fi

if [ ! -d "$tr_dir" ]; then
    echo "$0: translations directory does not exist: $tr_dir" >&2
    exit 1
fi

tmp_out=$(mktemp) || exit 1
trap 'rm -f "$tmp_out"' EXIT HUP INT TERM

total=0
changed=0
failed=0

while IFS= read -r line; do
    # Pass through comments and empty lines unchanged.
    case "$line" in
        '#'*|'')
            printf '%s\n' "$line" >> "$tmp_out"
            continue
            ;;
    esac

    total=$((total + 1))

    # Parse fields.  Expect exactly five fields.
    src_path=$(printf '%s\n' "$line" | cut -d'|' -f1)
    target_path=$(printf '%s\n' "$line" | cut -d'|' -f2)
    orig_hash=$(printf '%s\n' "$line" | cut -d'|' -f3)
    last_existed=$(printf '%s\n' "$line" | cut -d'|' -f4)
    git_hash=$(printf '%s\n' "$line" | cut -d'|' -f5)

    nfields=$(printf '%s\n' "$line" | awk -F'|' '{print NF}')
    if [ "$nfields" -ne 5 ]; then
        echo "$0: malformed line (expected 5 fields, got $nfields): $line" >&2
        printf '%s\n' "$line" >> "$tmp_out"
        failed=$((failed + 1))
        continue
    fi

    # Compute candidate paths in the translation store.
    orig_file="$tr_dir/${orig_hash%${orig_hash#??}}/$orig_hash"
    last_file="$tr_dir/${last_existed%${last_existed#??}}/$last_existed"

    if [ -f "$orig_file" ]; then
        new_last=$orig_hash
    elif [ -f "$last_file" ]; then
        new_last=$last_existed
    else
        new_last=$orig_hash
    fi

    if [ "$new_last" != "$last_existed" ]; then
        changed=$((changed + 1))
        [ "$verbose" -eq 1 ] && echo "$src_path: $last_existed -> $new_last"
    fi

    printf '%s|%s|%s|%s|%s\n' \
        "$src_path" "$target_path" "$orig_hash" "$new_last" "$git_hash" \
        >> "$tmp_out"
done < "$meta_file"

if [ "$dry_run" -eq 0 ]; then
    rm -f "$meta_file.bak"
    cp -p "$meta_file" "$meta_file.bak"
    mv "$tmp_out" "$meta_file"
    trap - EXIT HUP INT TERM
fi

if [ "$quiet" -eq 0 ]; then
    echo "Meta file:      $meta_file"
    echo "Translations:   $tr_dir"
    echo "Lines total:    $total"
    echo "Lines changed:  $changed"
    if [ "$dry_run" -eq 1 ]; then
        echo "Mode:           dry run (no changes written)"
    else
        echo "Backup:         $meta_file.bak"
    fi
fi

if [ "$failed" -gt 0 ]; then
    exit 2
fi

exit 0
