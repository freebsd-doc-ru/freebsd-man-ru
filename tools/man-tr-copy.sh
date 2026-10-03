#!/usr/bin/env sh
#
# Copyright (c) 2026 FreeBSD Russian Documentation Project
# Copyright (c) 2026 Vladlen Popolitov
#
# SPDX-License-Identifier: BSD-2-Clause
#
# man-tr-copy.sh -- copy translated man pages into the translation store.
#
# Each source file must contain a header of the form:
#
#   .\" FRDP path ./contrib/elftoolchain/addr2line/addr2line.1
#   .\" FRDP githash ae500c1ff8974130f7f2692772cf288b90349e0d
#   .\" FRDP hash256 0339e06a503b4f31c1f5ad8c06b35d2ade2ea63a5291ac7f75efd70a5f903921
#
# The value of the "hash256" field is used as the destination file name.
# The file is placed into a subdirectory named after the first two
# characters of the hash, relative to the destination directory:
#
#   <dst-dir>/<hh>/<hash>
#
# Usage:
#   man-tr-copy.sh [--force] [-v] <src-dir> <dst-dir>
#
# Options:
#   --force   Overwrite the destination file if it already exists.
#   -v        Print the name of each copied file.
#
# Exit status:
#   0   all files processed without error
#   1   usage error, missing source or destination directory
#   2   one or more source files were skipped
#

set -u

usage() {
    cat <<EOF
Usage: $0 [--force] [-v] <src-dir> <dst-dir>

Options:
  --force   Overwrite the destination file if it already exists.
  -v        Print the name of each copied file.
EOF
    exit 1
}

force=0
verbose=0

while [ $# -gt 0 ]; do
    case "$1" in
        --force)
            force=1
            shift
            ;;
        -v)
            verbose=1
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

src_dir=$1
dst_dir=$2

if [ ! -d "$src_dir" ]; then
    echo "$0: source directory does not exist: $src_dir" >&2
    exit 1
fi

if [ ! -d "$dst_dir" ]; then
    echo "$0: destination directory does not exist: $dst_dir" >&2
    exit 1
fi

# SHA-256 in hex is exactly 64 characters.
hash_len=64

skipped=0

# Iterate over regular files directly in src_dir (non-recursive).
for src in "$src_dir"/*; do
    [ -f "$src" ] || continue

    # Extract the hash256 field from the header.
    # The header may appear anywhere in the file, so we read the whole file.
    hash=$(sed -n 's/^\.\\" FRDP hash256 \([0-9a-fA-F]*\)$/\1/p' "$src" | head -n 1)

    if [ -z "$hash" ]; then
        echo "$0: no hash256 header in $src, skipping" >&2
        skipped=1
        continue
    fi

    # Validate: exactly 64 hex characters.
    case "$hash" in
        *[!0-9a-fA-F]*)
            echo "$0: malformed hash256 in $src (non-hex), skipping" >&2
            skipped=1
            continue
            ;;
    esac

    if [ "${#hash}" -ne "$hash_len" ]; then
        echo "$0: malformed hash256 in $src (length ${#hash}, expected $hash_len), skipping" >&2
        skipped=1
        continue
    fi

    prefix=$(printf '%s' "$hash" | cut -c1-2)
    dst="$dst_dir/$prefix/$hash"

    if [ -e "$dst" ] && [ "$force" -eq 0 ]; then
        echo "$0: destination exists, skipping: $dst" >&2
        skipped=1
        continue
    fi

    mkdir -p "$dst_dir/$prefix"
    cp -p "$src" "$dst"

    if [ "$verbose" -eq 1 ]; then
        echo "$src -> $dst"
    fi
done

if [ "$skipped" -eq 1 ]; then
    exit 2
fi

exit 0
