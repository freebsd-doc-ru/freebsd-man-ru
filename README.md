# FreeBSD Russian Manual Pages

## Страницы Справочника FreeBSD на русском языке

Russian translations of FreeBSD manual pages, distributed as
packages for each supported FreeBSD release.

## What this is

This repository contains Russian translations of man pages from
the FreeBSD source tree. Each translation is stored once and
reused across FreeBSD versions — if a man page is identical
between two releases, its translation is identical too, and is
not duplicated.

From this repository, separate packages are built for each
supported FreeBSD version (14.x, 15.x, main). Installing the
package places the translated pages under `man/ru/`, so that
`man(1)` finds them automatically when `LANG=ru_RU.UTF-8`.

## Repository layout

    translations/ru/       Translated man pages, addressed by the
                           SHA-512 hash of the original page.
                           Split into 256 subdirectories (00..ff)
                           by the first two hex digits of the hash.

    meta/                  Metadata files describing the state of
                           the upstream source tree for each
                           FreeBSD branch.

    tools/                 Scripts used to update metadata and to
                           prepare translations for packaging.

## How translations are stored

Each translated page lives under `translations/ru/<hash>`, where
`<hash>` is the SHA-512 hash of the original English page after
comments are removed. There are no file extensions — the hash is
the name.

This makes the storage content-addressable: the same original
page always maps to the same translation file, regardless of
which FreeBSD version it came from. Duplicates are impossible.

## How versions are tracked

Per-version metadata lives in `meta/<branch>.tsv`. Each line has
four fields separated by `|`:

    src_path|target_path|orig_hash|last_existed_orig_hash

  * `src_path`              Path in the FreeBSD source tree.
  * `target_path`           Install path under man/ru/.
  * `orig_hash`             SHA-512 hash of the current original.
  * `last_existed_orig_hash` Hash of the original for which a
                            translation file currently exists.

The fourth field is what keeps translated pages from disappearing
when the original changes. If the original is updated but the
translation has not yet been refreshed, the previous translation
is still shipped.

Metadata files are generated from a scan of the upstream source
tree. They are not edited by hand.

## Branches

The `main` branch holds all translations and tools. This is where
development happens.

Per-version branches are created automatically from `main` and
follow the naming scheme `lang_srcbranch`, for example:

    ru_releng/14.5      translations for FreeBSD 14.5
    ru_releng/15.0      translations for FreeBSD 15.0
    ru_stable/14        translations for FreeBSD stable/14
    ru_main             translations for FreeBSD main

These branches are read-only snapshots. Do not commit to them
directly — all changes must go to `main` and are picked up from
there. Tags are created on per-version branches, named after the
version, for example `ru_releng/14.5.0`.

## Tools usage:

Check files in directory `man/15.0R/ru.UTF-8/man1` against repo `~/freebsd-src`
and copy fixed filex (recalculated hash256) to directory `man/fixed`. 
Just in case hash256 calculated wrong, but githash is correct.

```sh
tools/man-tr-verify.sh man/15.0R/ru.UTF-8/man1  ~/freebsd-src man/fixed
```

Copy translated files from source directory `man/fixed` to final storage in `translations/ru`

```sh
tools/man-tr-copy.sh -v man/fixed  translations/ru
```

Verify metadata file `meta/releng15.1.tsv` (check if old translation is not needed anymore), when new translations are added
into a directory `translations/ru`. Must be run before man-tr-scan

```sh
tools/man-tr-fix.sh meta/releng15.1.tsv translations/ru
```

Scan repository `~/freebsd-src/` (it must be checked out to required branch manually before run) and rewrite
metadata file `meta/releng15.0.tsv`. Previous copy of metadata saved in `meta/releng15.0.tsv.bak`. man files stored as symbolic-links are skipped.

-s 1 - siffixes of man files (default - 1). 
Example: 
-s 1,8
-s 148

```sh
tools/man-tr-scan.sh -s 1 ~/freebsd-src/  meta/releng15.0.tsv
```

Recomended run sequence:
```sh
tools/man-tr-fix.sh ...
tools/man-tr-scan.sh ...
tools/man-tr-fix.sh ...
```

Copy translation from a directory `translations/ru` using metadata file `meta/releng15.0.tsv` to the directory `target15.0`
in the format of usual man files layout ( `man1`, `man2` etc).

```sh
tools/man-tr-assemble.sh meta/releng15.0.tsv translations/ru target15.0
```




## Contributing

Contributions of new translations and fixes to existing ones are
welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

Copyright (c) 2026 FreeBSD Russian Documentation Project
BSD-2-Clause. See individual files for details.
