#!/usr/bin/env sh
#
# Copyright (c) 2026 FreeBSD Russian Documentation Project
# Copyright (c) 2026 Vladlen Popolitov
#
# SPDX-License-Identifier: BSD-2-Clause
#
# man-tr-assemble.sh -- assemble man pages into a target directory.
#
# Reads a metadata file and copies translated man pages from the
# translation store into a target directory, laying them out under
# their real names and paths.
#
# The metadata file has five fields per line, separated by "|":
#
#   src_path|target_path|orig_hash|last_existed_orig_hash|git_commit_hash
#
# For each non-comment line, the source file is chosen as follows:
#
#   1. If the translation file for orig_hash exists, it is used.
#   2. Otherwise, if the translation file for last_existed_orig_hash
#      exists and last_existed_orig_hash differs from orig_hash,
#      it is used.
#   3. Otherwise the line is skipped silently (no translation).
#
# The chosen file is copied to <dst-dir>/<target_path>.  All
# intermediate directories are created as needed.
#
# Lines starting with "#" are treated as comments and ignored.
#
# Usage:
#   man-tr-assemble.sh [-q] [-v] [-n] [-s] <meta-file> <tr-dir> <dst-dir>
#
# Options:
#   -q   Quiet: print nothing on success.
#   -v   Verbose: print each copied file.
#   -n   Dry run: do not copy anything.
#   -s   Skip existing target files instead of overwriting them.
#
# Exit status:
#   0   success
#   1   usage error, missing meta file, missing tr dir, or missing dst dir
#   2   one or more lines could not be processed
#

set -u

usage() {
    cat <<EOF
Usage: $0 [-q] [-v] [-n] [-s] <meta-file> <tr-dir> <dst-dir>

Options:
  -q   Quiet: print nothing on success.
  -v   Verbose: print each copied file.
  -n   Dry run: do not copy anything.
  -s   Skip existing target files instead of overwriting them.
EOF
    exit 1
}

quiet=0
verbose=0
dry_run=0
skip_existing=0

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
        -s)
            skip_existing=1
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

if [ $# -ne 3 ]; then
    usage
fi

meta_file=$1
tr_dir=$2
dst_dir=$3

if [ ! -f "$meta_file" ]; then
    echo "$0: meta file does not exist: $meta_file" >&2
    exit 1
fi

if [ ! -d "$tr_dir" ]; then
    echo "$0: translations directory does not exist: $tr_dir" >&2
    exit 1
fi

if [ ! -d "$dst_dir" ]; then
    echo "$0: destination directory does not exist: $dst_dir" >&2
    exit 1
fi

total=0
copied=0
skipped=0
failed=0

while IFS= read -r line; do
    # Ignore comments and empty lines.
    case "$line" in
        '#'*|'')
            continue
            ;;
    esac

    total=$((total + 1))

    nfields=$(printf '%s\n' "$line" | awk -F'|' '{print NF}')
    if [ "$nfields" -ne 5 ]; then
        echo "$0: malformed line (expected 5 fields, got $nfields): $line" >&2
        failed=$((failed + 1))
        continue
    fi

    src_path=$(printf '%s\n' "$line" | cut -d'|' -f1)
    target_path=$(printf '%s\n' "$line" | cut -d'|' -f2)
    orig_hash=$(printf '%s\n' "$line" | cut -d'|' -f3)
    last_existed=$(printf '%s\n' "$line" | cut -d'|' -f4)

    # Sanity: both hashes must be non-empty.
    if [ -z "$orig_hash" ] || [ -z "$last_existed" ]; then
        echo "$0: empty hash in line: $line" >&2
        failed=$((failed + 1))
        continue
    fi

    # Choose the source file.
    file_orig="$tr_dir/${orig_hash%${orig_hash#??}}/$orig_hash"
    file_last="$tr_dir/${last_existed%${last_existed#??}}/$last_existed"

    source_file=""
    if [ -f "$file_orig" ]; then
        source_file=$file_orig
    elif [ "$last_existed" != "$orig_hash" ] && [ -f "$file_last" ]; then
        source_file=$file_last
    fi

    if [ -z "$source_file" ]; then
        # No translation for this line.  Normal situation.
        skipped=$((skipped + 1))
        continue
    fi

    # Build the destination path.
    dst="$dst_dir/$target_path"

    if [ -e "$dst" ] && [ "$skip_existing" -eq 1 ]; then
        echo "$0: target exists, skipping: $dst" >&2
        skipped=$((skipped + 1))
        continue
    fi

    if [ "$dry_run" -eq 1 ]; then
        [ "$verbose" -eq 1 ] && echo "$source_file -> $dst"
        copied=$((copied + 1))
        continue
    fi

    # Create intermediate directories for the target path.
    dst_parent=$(dirname "$dst")
    mkdir -p "$dst_parent"

    cp -p "$source_file" "$dst"
    copied=$((copied + 1))

    [ "$verbose" -eq 1 ] && echo "$source_file -> $dst"
done < "$meta_file"

if [ "$quiet" -eq 0 ]; then
    echo "Meta file:    $meta_file"
    echo "Translations: $tr_dir"
    echo "Destination:  $dst_dir"
    echo "Lines total:  $total"
    echo "Copied:       $copied"
    echo "Skipped:      $skipped"
    if [ "$dry_run" -eq 1 ]; then
        echo "Mode:         dry run (no files copied)"
    fi
    if [ "$skip_existing" -eq 1 ]; then
        echo "Existing:     skipped"
    else
        echo "Existing:     overwritten"
    fi
fi

if [ "$failed" -gt 0 ]; then
    exit 2
fi

exit 0
