#!/usr/bin/env sh

if [ -z "$1" ]; then
    echo "Usage: $0 tag_number"
    git -C ~/freebsd-man-ru-branches checkout ru_releng/15.0
    git -C /Users/vladlenpopolitov/freebsd-man-ru-branches tag | grep ru_releng/15.0
    exit 1
fi

git -C ~/freebsd-man-ru-branches checkout ru_releng/15.0
git -C ~/freebsd-man-ru-branches pull
mkdir ~/freebsd-man-ru-branches/man
~/freebsd-man-ru/tools/man-tr-assemble.sh ~/freebsd-man-ru/meta/releng15.0.tsv \
    ~/freebsd-man-ru/translations/ru ~/freebsd-man-ru-branches/man/
git -C ~/freebsd-man-ru-branches add man/
git -C ~/freebsd-man-ru-branches add -u
git -C ~/freebsd-man-ru-branches status
git -C ~/freebsd-man-ru-branches commit -m "Translation updated"
git -C ~/freebsd-man-ru-branches push origin ru_releng/15.0
git -C /Users/vladlenpopolitov/freebsd-man-ru-branches tag | grep ru_releng/15.0
git -C ~/freebsd-man-ru-branches tag ru_releng/15.0-$1
git -C ~/freebsd-man-ru-branches push origin ru_releng/15.0-$1
