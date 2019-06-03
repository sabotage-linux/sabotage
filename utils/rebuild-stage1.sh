#!/bin/sh
# use: rebuild-stage1.sh [no args]
# Rebuilds the stage0/1 binaries with the stage 1 compiler.

# The resulting binaries/package directories should be
# identical to binaries produced on different systems
# (can be verified with `butch checksum`)

base_pkg='
libz
gmp
mpfr
mpc
libelf
gcc650
musl
jobflow
patch
busybox
binutils
make
sabotage-core
join
'

ext_pkg='
kbd
m4
9base
pkgconf
libblkid
e2fsprogs
man
libressl
ca-certificates
'

pkg="$base_pkg"
test "$1" = --base || pkg="$base_pkg$ext_pkg"

pkg=$(printf "%s\n" "$pkg" | sed '/^$/d' | tr '\n' ' ')

butch rebuild $pkg
