#!/bin/sh
set +e

help () {
	cat <<EOF
Syntax: mkcpio.sh <path to system root> <destination filename>

This program will pack an compiled system into an gzipped cpio archive.
When booting, the bootloader can pass along an cpio archive with the kernel.
The kernel will extract the archive into RAM as / and execute /init.

The system needs to have an valid /init file or booting the resulting image
will result in an kernel panic.

/src/build and /src/log will be omitted. Beside from that, this script is not
specific to Sabotage and may be used on other Linux distributions.
EOF
}

[ -z "$2" ] && help >/dev/stderr && exit 1
[ "$1" = "-h" ] && help && exit

[ -x "$1/init" ] || echo "WARN: $1/init does not exist or is not executable, the cpio wont be able to boot" 2>/dev/stderr

# List all files, the grep will exclude all entries from "bad" directories,
# but will leave the directories itself as empty stubs for overmounting.
# The archive will be piped through gzip.
# TODO: investigate whether gzip -9 is useful here and portable
( cd "$1" && find . | grep -v -E '^\./(boot|sys|proc|dev|src/build|src/log)/.*' | exec cpio -H newc -o ) | gzip > "$2"
