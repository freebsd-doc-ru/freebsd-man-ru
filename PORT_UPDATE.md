# Ports update procedure

## Clone freebsd-ru-man as source

git clone git clone  https://github.com/freebsd-doc-ru/freebsd-man-ru ~/freebsd-man-ru
cd ~/freebsd-man-ru
git chechout main
git pull


## Clone freebsd-ru-man as target to prepare eports-source

FreeBSD `main` branch corresponds to `ru_main` branch with translations to Russian.

git clone git clone  https://github.com/freebsd-doc-ru/freebsd-man-ru freebsd-man-ru-branches

## Assemble translated data in target directory and opublish them

### copy and rename files

```sh
cd ~/freebsd-man-ru-branches
git chechout ru_main
git pull
~/freebsd-man-ru/tools/man-tr-assemble.sh ~/freebsd-man-ru/meta/main.tsv \
    ~/freebsd-man-ru/translations/ru ~/freebsd-man-ru-branches/man/
```

### add new files

```sh
git -C ~/freebsd-man-ru-branches add man/
git -C ~/freebsd-man-ru-branches add -u
git -C ~/freebsd-man-ru-branches status
git -C ~/freebsd-man-ru-branches commit -m "Translation updated"
```

### Publish translation for version (version 1)

```sh
git -C ~/freebsd-man-ru-branches tag ru_main-1
git -C ~/freebsd-man-ru-branches push origin ru_main
git -C ~/freebsd-man-ru-branches push origin ru_main-1
```

## Create new branch for new FreeBSD version

```sh
git -C ~/freebsd-man-ru-branches checkout version_branch
git -C ~/freebsd-man-ru-branches checkout -b ru_releng/15.0
git -C ~/freebsd-man-ru-branches checkout -b ru_stable/15 
```