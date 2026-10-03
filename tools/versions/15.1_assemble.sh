git -C ~/freebsd-man-ru-branches checkout ru_releng/15.1
git -C ~/freebsd-man-ru-branches pull
~/freebsd-man-ru/tools/man-tr-assemble.sh ~/freebsd-man-ru/meta/releng15.1.tsv \
    ~/freebsd-man-ru/translations/ru ~/freebsd-man-ru-branches/man/
git -C ~/freebsd-man-ru-branches add man/
git -C ~/freebsd-man-ru-branches add -u
git -C ~/freebsd-man-ru-branches status
git -C ~/freebsd-man-ru-branches commit -m "Translation updated"
git -C ~/freebsd-man-ru-branches push origin ru_releng/15.1
git -C /Users/vladlenpopolitov/freebsd-man-ru-branches tag | grep ru_releng/15.1
echo git -C ~/freebsd-man-ru-branches tag ru_releng/15.1-'?'
echo git -C ~/freebsd-man-ru-branches push origin ru_releng/15.1-'?'
