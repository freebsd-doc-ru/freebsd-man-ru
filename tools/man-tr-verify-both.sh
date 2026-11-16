#!/usr/bin/env sh
#
# man-tr-verify-both.sh -- verify AND fix translated man pages,
# writing the result to a separate output directory.
#
# Read-only w.r.t. <src-dir> and <git-dir>.  For every regular file
# in <src-dir>, reads the FRDP header:
#
#   .\" FRDP path    <path-in-repo>
#   .\" FRDP githash <commit-sha1>
#   .\" FRDP hash256 <sha256-of-original>
#
# and writes a copy to <dst-dir> under the same basename.  Two things
# may be corrected in the copy:
#
#   1. githash: if the declared commit does not resolve to the same
#      blob for <path> as the current HEAD of <git-dir>, it is
#      rewritten to the HEAD commit.
#
#   2. hash256: if it does not equal SHA-256 of the current HEAD
#      version of <path> with comment lines (starting with .\")
#      removed, it is rewritten to that computed value.
#
# Files that need no corrections are copied unchanged.  Statistics at
# the end show how many files had githash fixed and how many had
# hash256 fixed.
#
# Usage:
#   man-tr-verify-both.sh [-q] [-v] <src-dir> <git-dir> <dst-dir>
#
# Options:
#   -q   Quiet: print nothing on success.
#   -v   Verbose: print each file and what was corrected.
#
# Exit status:
#   0   all files verified/copied successfully
#   1   usage error or missing directory / not a git repository
#   2   one or more files could not be verified and were skipped
#

set -u

usage() {
    cat <<EOF
Usage: $0 [-q] [-v] <src-dir> <git-dir> <dst-dir>

Options:
  -q   Quiet: print nothing on success.
  -v   Verbose: print each file and what was corrected.

<src-dir> and <git-dir> are read-only.  All output (including files
that needed no corrections) is written to <dst-dir>.
EOF
    exit 1
}

quiet=0
verbose=0

while [ $# -gt 0 ]; do
    case "$1" in
        -q) quiet=1; shift ;;
        -v) verbose=1; shift ;;
        --) shift; break ;;
        -*) echo "$0: unknown option: $1" >&2; usage ;;
        *)  break ;;
    esac
done

if [ $# -ne 3 ]; then
    usage
fi

src_dir=$1
git_dir=$2
dst_dir=$3

if [ ! -d "$src_dir" ]; then
    echo "$0: source directory does not exist: $src_dir" >&2
    exit 1
fi

if [ ! -d "$git_dir" ]; then
    echo "$0: git directory does not exist: $git_dir" >&2
    exit 1
fi

if [ ! -d "$dst_dir" ]; then
    echo "$0: destination directory does not exist: $dst_dir" >&2
    exit 1
fi

if ! git -C "$git_dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "$0: not a git repository: $git_dir" >&2
    exit 1
fi

head_commit=$(git -C "$git_dir" rev-parse HEAD 2>/dev/null)
if [ -z "$head_commit" ]; then
    echo "$0: cannot resolve HEAD in $git_dir" >&2
    exit 1
fi

# Blob hash of <path> in HEAD (empty if not present).
head_blob_for() {
    git -C "$git_dir" rev-parse --verify "HEAD:$1" 2>/dev/null
}

# SHA-256 of <path> at <rev>, roff comment lines (starting with .\")
# removed.  Empty on failure.
sha256_of_blob() {
    rev=$1
    path=$2
    git -C "$git_dir" show "$rev:$path" 2>/dev/null \
        | sed '/^\.\\"/d' \
        | openssl dgst -sha256 \
        | sed 's/^.*= //'
}

total=0
ok=0
fixed_githash=0
fixed_hash256=0
fixed_both=0
skipped=0

for src in "$src_dir"/*; do
    [ -f "$src" ] || continue

    total=$((total + 1))
    base=$(basename "$src")
    dst="$dst_dir/$base"

    path=$(sed -n 's/^\.\\" FRDP path[[:space:]]\{1,\}\(.*\)$/\1/p' "$src" | head -n 1)
    githash=$(sed -n 's/^\.\\" FRDP githash[[:space:]]\{1,\}\([0-9a-fA-F]*\)$/\1/p' "$src" | head -n 1)
    hash256=$(sed -n 's/^\.\\" FRDP hash256[[:space:]]\{1,\}\([0-9a-fA-F]*\)$/\1/p' "$src" | head -n 1)

    if [ -z "$path" ] || [ -z "$githash" ] || [ -z "$hash256" ]; then
        echo "$0: incomplete FRDP header in $src, skipping" >&2
        skipped=$((skipped + 1))
        continue
    fi

    head_blob=$(head_blob_for "$path")
    if [ -z "$head_blob" ]; then
        echo "$0: path '$path' not found in HEAD of $git_dir, skipping $src" >&2
        skipped=$((skipped + 1))
        continue
    fi

    declared_blob=$(git -C "$git_dir" rev-parse --verify \
        "$githash:$path" 2>/dev/null)

    need_githash_fix=0
    if [ -z "$declared_blob" ] || [ "$declared_blob" != "$head_blob" ]; then
        need_githash_fix=1
    fi

    computed=$(sha256_of_blob "$head_commit" "$path")
    if [ -z "$computed" ]; then
        echo "$0: cannot compute SHA-256 for '$path' at HEAD, skipping $src" >&2
        skipped=$((skipped + 1))
        continue
    fi

    need_hash256_fix=0
    if [ "$computed" != "$hash256" ]; then
        need_hash256_fix=1
    fi

    # Build the output file.  Start from a verbatim copy and patch
    # only the fields that need fixing.
    cp "$src" "$dst" || {
        echo "$0: cannot write $dst, skipping $src" >&2
        skipped=$((skipped + 1))
        rm -f "$dst"
        continue
    }

    if [ "$need_githash_fix" -eq 1 ]; then
        tmp="$dst.tmp.$$"
        sed "s|^\(\.\\\\\" FRDP githash \).*|\1$head_commit|" "$dst" > "$tmp"
        mv "$tmp" "$dst"
    fi
    if [ "$need_hash256_fix" -eq 1 ]; then
        tmp="$dst.tmp.$$"
        sed "s|^\(\.\\\\\" FRDP hash256 \).*|\1$computed|" "$dst" > "$tmp"
        mv "$tmp" "$dst"
    fi
    
    # Statistics.
    if [ "$need_githash_fix" -eq 1 ] && [ "$need_hash256_fix" -eq 1 ]; then
        fixed_both=$((fixed_both + 1))
        fixed_githash=$((fixed_githash + 1))
        fixed_hash256=$((fixed_hash256 + 1))
        status="fixed githash+hash256"
    elif [ "$need_githash_fix" -eq 1 ]; then
        fixed_githash=$((fixed_githash + 1))
        status="fixed githash"
    elif [ "$need_hash256_fix" -eq 1 ]; then
        fixed_hash256=$((fixed_hash256 + 1))
        status="fixed hash256"
    else
        ok=$((ok + 1))
        status="ok"
    fi

    if [ "$verbose" -eq 1 ]; then
        echo "$src -> $dst: $status"
        if [ "$need_githash_fix" -eq 1 ]; then
            echo "    githash: $githash -> $head_commit" >&2
        fi
        if [ "$need_hash256_fix" -eq 1 ]; then
            echo "    hash256: $hash256 -> $computed" >&2
        fi
    fi
done

if [ "$quiet" -eq 0 ]; then
    echo "Source:          $src_dir"
    echo "Git:             $git_dir (HEAD $head_commit)"
    echo "Dest:            $dst_dir"
    echo "Total:           $total"
    echo "OK (unchanged):  $ok"
    echo "Fixed githash:   $fixed_githash"
    echo "Fixed hash256:   $fixed_hash256"
    echo "Fixed both:      $fixed_both"
    echo "Skipped:         $skipped"
fi

if [ "$skipped" -gt 0 ]; then
    exit 2
fi

exit 0
