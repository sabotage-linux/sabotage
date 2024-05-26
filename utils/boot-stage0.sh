#!/bin/sh
# /src/utils/boot-stage0.sh

set -e

ARCH=$(uname -m)
MAKE_THREADS=$(nproc)

mkdir -p /sabotage
ln -sf /src /sabotage/
cd /sabotage/src

cp KEEP/config.stage0 config
# Need to identify as GNUC as otherwise libtool gets confused and screws up linker flags
sed -e "s@SABOTAGE_BUILDDIR=.*@SABOTAGE_BUILDDIR=/sabotage@" \
    -e "s@CC=.*@CC='cc -D__GNUC__'@" -e "s@HOSTCC=.*@HOSTCC=cc@" \
    -e "s@MAKE_THREADS=1@MAKE_THREADS=$MAKE_THREADS@" \
    -i config
echo "export GCC_ARCH_CONFIG_FLAGS='--host=$ARCH-unknown-linux-gnu'" >> config

utils/setup-rootfs.sh

export CONFIG=/sabotage/src/config BUTCHDB=/sabotage/var/lib/butch.db

KEEP/bin/butch install make-bootstrap
ln -sf /sabotage/opt/make-bootstrap/bin/* /bin/

KEEP/bin/butch install bearssl
ln -sf /sabotage/opt/bearssl/include/* /include/
ln -sf /sabotage/opt/bearssl/lib/* /lib/

KEEP/bin/butch install curl-bearssl
ln -sf /sabotage/opt/curl-bearssl/bin/* /bin/

KEEP/bin/butch install binutils
ln -sf /sabotage/opt/binutils/bin/* /bin/

DEPS=build:stage0 KEEP/bin/butch install stage0

unset CONFIG BUTCHDB

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

cd
exec sh
