git -C ~/freebsd-man-ru-branches checkout ru_main
git -C ~/freebsd-man-ru-branches pull
~/freebsd-man-ru/tools/man-tr-assemble.sh ~/freebsd-man-ru/meta/main.tsv \
    ~/freebsd-man-ru/translations/ru ~/freebsd-man-ru-branches/man/
git -C ~/freebsd-man-ru-branches add man/
git -C ~/freebsd-man-ru-branches add -u
git -C ~/freebsd-man-ru-branches status
git -C ~/freebsd-man-ru-branches commit -m "Translation updated"
git -C ~/freebsd-man-ru-branches push origin ru_main
echo git -C ~/freebsd-man-ru-branches tag ru_main-'?'
echo git -C ~/freebsd-man-ru-branches push origin ru_main-'?'
