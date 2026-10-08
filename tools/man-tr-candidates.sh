#!/usr/bin/env sh
#
# man-tr-candidates.sh -- list man pages that need translation.
#
# Reads a metadata file, checks which entries already have a
# translation file in the translation store, and writes a list of
# candidates for translation into an output file.
#
# An entry is a candidate if its orig_hash (field 3) has no
# corresponding file in <tr-dir>/<hh>/<orig_hash>.  The fourth field
# (last_existed_orig_hash) is ignored for the purpose of this tool.
#
# Because several source files may share the same target_path, the
# tool performs two passes:
#
#   1. First pass: collect target_path values of translated entries
#      into a temporary file.  These paths are considered "taken".
#
#   2. Second pass: go through the metadata file in order.  For each
#      entry:
#        - if its orig_hash is translated, skip silently;
#        - if its target_path is in the translated set, print a
#          warning and skip it;
#        - if its target_path is already in the candidate set, print
#          a warning and skip it;
#        - otherwise add it to the candidate set and to the output.
#
# Output format: tab-separated fields, one line per candidate:
#
#   name<TAB>section<TAB>version<TAB>src_path<TAB>git_hash<TAB>orig_hash<TAB>count
#
# where:
#   name      -- file name without the trailing .<digit> section suffix
#   section   -- the section number (the .<digit> suffix)
#   version   -- the metadata file name without the directory and
#                without the .tsv extension (e.g. "14" for meta/14.tsv)
#   src_path  -- source path from the metadata
#   git_hash  -- git commit hash of the last change to the source file
#   orig_hash -- SHA-256 hash of the original file
#   count     -- how many .tsv files in the translation store mention
#                this orig_hash (the original hash, not the translation
#                hash); used as the primary sort key (descending)
#
# Usage:
#   man-tr-candidates.sh [-q] [-f] <meta-file> <tr-dir> <out-file>
#
# Options:
#   -q   Quiet: print nothing on success.
#   -f   Force: overwrite the output file if it already exists.
#
# Exit status:
#   0   success
#   1   usage error, missing input, or output file already exists
#   2   one or more metadata lines could not be processed
#

set -u

usage() {
    cat <<EOF
Usage: $0 [-q] [-f] <meta-file> <tr-dir> <out-file>

Options:
  -q   Quiet: print nothing on success.
  -f   Force: overwrite the output file if it already exists.
EOF
    exit 1
}

quiet=0
force=0

while [ $# -gt 0 ]; do
    case "$1" in
        -q)
            quiet=1
            shift
            ;;
        -f)
            force=1
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
out_file=$3

if [ ! -f "$meta_file" ]; then
    echo "$0: meta file does not exist: $meta_file" >&2
    exit 1
fi

if [ ! -d "$tr_dir" ]; then
    echo "$0: translations directory does not exist: $tr_dir" >&2
    exit 1
fi

if [ -e "$out_file" ] && [ "$force" -eq 0 ]; then
    echo "$0: output file already exists: $out_file" >&2
    echo "$0: use -f to overwrite" >&2
    exit 1
fi

# Version = metadata file name without directory and .tsv extension.
meta_base=$(basename "$meta_file")
version=${meta_base%.tsv}

tmp_translated=$(mktemp) || exit 1
tmp_candidates=$(mktemp) || exit 1
tmp_out=$(mktemp) || exit 1
trap 'rm -f "$tmp_translated" "$tmp_candidates" "$tmp_out"' EXIT HUP INT TERM

# Temporary file with hash -> count mapping.
tmp_hashcount=$(mktemp) || exit 1
trap 'rm -f "$tmp_translated" "$tmp_candidates" "$tmp_out" "$tmp_hashcount"' EXIT HUP INT TERM

# --- Index pass: count occurrences of each orig_hash in all .tsv files. ---
# The .tsv files list translations; the third field (between the second
# and third '|') is the original hash.  Count how many such files contain
# each hash.  Duplicate lines within a single file are not expected, but
# if they occur, they are still counted once per file per line — see below.
# Directory containing the metadata file — the .tsv files live there.
meta_dir=$(dirname "$meta_file")

# --- Index pass: count occurrences of each orig_hash in all .tsv files. ---
find "$meta_dir" -type f -name '*.tsv' -print | while IFS= read -r tsv; do
    awk -F'|' 'NF >= 5 && $3 != "" { print $3 }' "$tsv"
done | sort | uniq -c | awk '{print $2 "\t" $1}' > "$tmp_hashcount"

total=0
candidates=0
skipped_translated=0
skipped_dup_translated=0
skipped_dup_candidate=0
failed=0

# --- First pass: collect target_path of translated entries. ---
while IFS= read -r line; do
    case "$line" in
        '#'*|'')
            continue
            ;;
    esac

    nfields=$(printf '%s\n' "$line" | awk -F'|' '{print NF}')
    if [ "$nfields" -ne 5 ]; then
        failed=$((failed + 1))
        continue
    fi

    target_path=$(printf '%s\n' "$line" | cut -d'|' -f2)
    orig_hash=$(printf '%s\n' "$line" | cut -d'|' -f3)

    if [ -z "$orig_hash" ]; then
        continue
    fi

    tr_file="$tr_dir/${orig_hash%${orig_hash#??}}/$orig_hash"
    if [ -f "$tr_file" ]; then
        printf '%s\n' "$target_path" >> "$tmp_translated"
    fi
done < "$meta_file"

# --- Second pass: process entries in order. ---
while IFS= read -r line; do
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
    git_hash=$(printf '%s\n' "$line" | cut -d'|' -f5)

    if [ -z "$orig_hash" ]; then
        echo "$0: empty orig_hash in line: $line" >&2
        failed=$((failed + 1))
        continue
    fi

    tr_file="$tr_dir/${orig_hash%${orig_hash#??}}/$orig_hash"

    # Translated entries are skipped silently.
    if [ -f "$tr_file" ]; then
        skipped_translated=$((skipped_translated + 1))
        continue
    fi

    # target_path is already taken by a translation.
    if grep -qxF "$target_path" "$tmp_translated" 2>/dev/null; then
        echo "$0: target_path already has a translation, skipping: $target_path" >&2
        skipped_dup_translated=$((skipped_dup_translated + 1))
        continue
    fi

    # target_path is already in the candidate list.
    if grep -qxF "$target_path" "$tmp_candidates" 2>/dev/null; then
        echo "$0: target_path already in candidate list, skipping: $target_path" >&2
        skipped_dup_candidate=$((skipped_dup_candidate + 1))
        continue
    fi

    # Add to candidate list.
    printf '%s\n' "$target_path" >> "$tmp_candidates"

    base=$(basename "$target_path")
    section=${base##*.}
    name=${base%.*}

    hash_count=$(awk -F'\t' -v h="$orig_hash" '$1 == h { print $2; exit }' "$tmp_hashcount")
    [ -n "$hash_count" ] || hash_count=0

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$name" "$section" "$version" "$src_path" "$git_hash" "$orig_hash" \
        "$hash_count" \
        >> "$tmp_out"

    candidates=$((candidates + 1))
done < "$meta_file"

# Sort by descending occurrence count (field 7), then by name (field 1),
# then by section (field 2), and write the result to the output file.
sort -t"$(printf '\t')" -k7,7nr -k1,1 -k2,2 "$tmp_out" > "$out_file"

if [ "$quiet" -eq 0 ]; then
    echo "Meta file:                    $meta_file"
    echo "Translations:                 $tr_dir"
    echo "Output:                       $out_file"
    echo "Lines total:                  $total"
    echo "Candidates:                   $candidates"
    echo "Skipped (translated):         $skipped_translated"
    echo "Skipped (dup translated):     $skipped_dup_translated"
    echo "Skipped (dup candidate):      $skipped_dup_candidate"
fi

if [ "$failed" -gt 0 ]; then
    exit 2
fi

exit 0
