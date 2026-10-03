# Contributing

Contributions to this project are welcome. Pull requests with
new translations and fixes to existing translations are accepted.

## What to send

Translations go into the `translations/ru/` directory. Each
translated man page is stored under a filename equal to the
SHA-512 hash of the original English page (with comments
removed). The file has no extension.

If you are adding a translation for a page that has not been
translated before, the hash is determined by the original page —
see `meta/` for the current mapping.

If you are fixing an existing translation, edit the file in
place. Do not rename it — the filename reflects the original
page, not the translation.

## Pull requests

Send pull requests against the `main` branch. Do not commit
directly to per-version branches (`ru_releng/...`, `ru_stable/...`,
`ru_main`) — these are generated automatically from `main` and
any changes committed there will be lost.

## Technical details

Detailed instructions on the translation format, the header
comment block, the metadata files, and the tooling will be
published separately. If you have questions in the meantime,
open an issue.
