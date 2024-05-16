#!/bin/sh

set -e

ARCH=$(uname -m)
MAKE_THREADS=$(nproc)

cd /root

make -s gawk binutils bzip2 curl linux-headers

mkdir -p /sabotage
ln -s /src /sabotage/src
cd /sabotage/src

cp KEEP/config.stage0 config
sed -e "s@SABOTAGE_BUILDDIR=.*@SABOTAGE_BUILDDIR=/sabotage@" \
    -e "s@CC=.*@CC=cc@" -e "s@HOSTCC=.*@HOSTCC=cc@" \
    -e "s@MAKE_THREADS=1@MAKE_THREADS=$MAKE_THREADS@" \
    -i config

utils/setup-rootfs.sh

CONFIG=/sabotage/src/config BUTCHDB=/sabotage/var/lib/butch.db DEPS=build:stage0 KEEP/bin/butch install stage0

echo "export A=$ARCH" > config && cat KEEP/config.stage1 >> config
sed -i "s@MAKE_THREADS=1@MAKE_THREADS=$MAKE_THREADS@" config

# Replace the rootfs with the one we just built

cd /
rm -rf root include lib local tmp usr
rm $(find /bin -type f -not -name sh)

[ -e /etc/hostname ] && mv /sabotage/etc/hostname /etc/hostname.bak
[ -e /etc/hosts ] && mv /sabotage/etc/hosts /etc/hosts.bak
[ -e /etc/resolv.conf ] && mv /sabotage/etc/resolv.conf /etc/resolv.conf.bak

mv /sabotage/bin/* /bin
mv /sabotage/etc/* /etc

rm /sabotage/src
rmdir /sabotage/bin /sabotage/etc /sabotage/dev /sabotage/proc /sabotage/sys

mv -f /sabotage/* /
rmdir /sabotage
