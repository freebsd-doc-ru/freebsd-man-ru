#!/usr/bin/env sh
#
# man-tr-verify.sh -- verify translated man pages against their originals.
#
# For each regular file in <src-dir>, reads the FRDP header:
#
#   .\" FRDP path    <path-in-repo>
#   .\" FRDP githash <commit-sha1>
#   .\" FRDP hash256 <sha256-of-original>
#
# Fetches the corresponding original from the git repository at
# <git-dir> using "git show <githash>:<path>", removes comment lines
# (those starting with .\"), computes SHA-256, and compares the result
# with the hash256 value from the header.
#
# If a third argument <dst-dir> is given, every file is copied there
# under its original name (not renamed to the hash).  Files are copied
# regardless of the verification result.
#
# Usage:
#   man-tr-verify.sh [-q] [-v] <src-dir> <git-dir> [<dst-dir>]
#
# Options:
#   -q   Quiet: print nothing on success.
#   -v   Verbose: print each file and its verification result.
#
# Exit status:
#   0   all files verified successfully
#   1   usage error or missing directory
#   2   one or more files failed verification or were skipped
#

set -u

usage() {
    cat <<EOF
Usage: $0 [-q] [-v] <src-dir> <git-dir> [<dst-dir>]

Options:
  -q   Quiet: print nothing on success.
  -v   Verbose: print each file and its verification result.
EOF
    exit 1
}

quiet=0
verbose=0

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

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    usage
fi

src_dir=$1
git_dir=$2
dst_dir=${3:-}

if [ ! -d "$src_dir" ]; then
    echo "$0: source directory does not exist: $src_dir" >&2
    exit 1
fi

if [ ! -d "$git_dir" ]; then
    echo "$0: git directory does not exist: $git_dir" >&2
    exit 1
fi

if [ -n "$dst_dir" ] && [ ! -d "$dst_dir" ]; then
    echo "$0: destination directory does not exist: $dst_dir" >&2
    exit 1
fi

total=0
ok=0
mismatch=0
skipped=0

for src in "$src_dir"/*; do
    [ -f "$src" ] || continue

    total=$((total + 1))

    path=$(sed -n 's/^\.\\" FRDP path[[:space:]]\{1,\}\(.*\)$/\1/p' "$src" | head -n 1)
    githash=$(sed -n 's/^\.\\" FRDP githash[[:space:]]\{1,\}\([0-9a-fA-F]*\)$/\1/p' "$src" | head -n 1)
    hash256=$(sed -n 's/^\.\\" FRDP hash256[[:space:]]\{1,\}\([0-9a-fA-F]*\)$/\1/p' "$src" | head -n 1)

    if [ -z "$path" ]; then
        echo "$0: no FRDP path in $src, skipping" >&2
        skipped=$((skipped + 1))
        continue
    fi
    if [ -z "$githash" ]; then
        echo "$0: no FRDP githash in $src, skipping" >&2
        skipped=$((skipped + 1))
        continue
    fi
    if [ -z "$hash256" ]; then
        echo "$0: no FRDP hash256 in $src, skipping" >&2
        skipped=$((skipped + 1))
        continue
    fi

    # Fetch original from git and compute its hash.
    # git show prints the blob to stdout.  If the commit or path is not
    # found, git exits non-zero and prints to stderr.
    computed=$(git -C "$git_dir" show "$githash:$path" 2>/dev/null \
        | sed '/^\.\\"/d' \
        | openssl dgst -sha256 \
        | sed 's/^.*= //')

    if [ -z "$computed" ]; then
        echo "$0: cannot fetch $path at $githash from $git_dir, skipping $src" >&2
        skipped=$((skipped + 1))
        continue
    fi

    if [ "$computed" = "$hash256" ]; then
        ok=$((ok + 1))
        result="ok"
    else
        mismatch=$((mismatch + 1))
        result="MISMATCH"
        echo "$0: hash mismatch in $src" >&2
        echo "    header:   $hash256" >&2
        echo "    computed: $computed" >&2
        echo "    path:     $path" >&2
        echo "    githash:  $githash" >&2
    fi

    if [ "$verbose" -eq 1 ]; then
        echo "$src: $result"
    fi

    # Copy to destination, if requested.  Copy regardless of result.
    if [ -n "$dst_dir" ]; then
        base=$(basename "$src")
        dst="$dst_dir/$base"
        sed "s|^\(\.\\\\\" FRDP hash256 \).*|\1$computed|" "$src" > "$dst"
    fi
done

if [ "$quiet" -eq 0 ]; then
    echo "Source:   $src_dir"
    echo "Git:      $git_dir"
    if [ -n "$dst_dir" ]; then
        echo "Dest:     $dst_dir"
    fi
    echo "Total:    $total"
    echo "OK:       $ok"
    echo "Mismatch: $mismatch"
    echo "Skipped:  $skipped"
fi

if [ "$mismatch" -gt 0 ] || [ "$skipped" -gt 0 ]; then
    exit 2
fi

exit 0
