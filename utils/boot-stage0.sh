#!/bin/sh

set -e

cd /root

make gawk binutils bzip2 curl linux-headers

mkdir -p /sabotage
ln -s /src /sabotage/src
cd /sabotage/src

cp KEEP/config.stage0 config
sed -e "s@SABOTAGE_BUILDDIR=.*@SABOTAGE_BUILDDIR=/sabotage@" \
    -e "s@CC=.*@CC=cc@" -e "s@HOSTCC=.*@HOSTCC=cc@" \
    -e "s@MAKE_THREADS=1@MAKE_THREADS=$(NPROC)@" \
    -i config && cat config

utils/setup-rootfs.sh

CONFIG=/sabotage/src/config BUTCHDB=/sabotage/var/lib/butch.db DEPS=build:stage0 KEEP/bin/butch install stage0

echo "export A=$(ARCH)" > config && cat KEEP/config.stage1 >> config
sed -i "s@MAKE_THREADS=1@MAKE_THREADS=$(NPROC)@" config && cat config
