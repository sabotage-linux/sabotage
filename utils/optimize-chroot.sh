#!/bin/sh
# use: optimize-chroot.sh [no args]
# Rebuilds the stage0/1 binaries with the stage 1 compiler.

butch rebuild jobflow sabotage-core patch busybox binutils make \
	kbd m4 gmp mpfr mpc libz libelf gcc640 musl 9base pkgconf \
	libblkid e2fsprogs man join libressl ca-certificates
