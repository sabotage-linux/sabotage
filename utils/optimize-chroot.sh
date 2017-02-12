#!/bin/sh
# use: optimize-chroot.sh [no args]
# Rebuilds the stage0/1 binaries with the stage 1 compiler.

butch rebuild jobflow patch busybox binutils make \
	m4 gmp mpfr mpc libz libelf gcc630 \
	musl 9base pkgconf libblkid e2fsprogs
