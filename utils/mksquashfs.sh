#!/bin/sh
set +e

help () {
	cat <<EOF
Syntax: mk-squashfs.sh <path to system root> <destination filename>

This program will pack an compiled system into an squashfs file. Virtual
filesystems like /dev, /proc and /sys are only preserved as mountpoint.

To boot into an squashed system, the kernel needs to start an initramfs
userspace first, which will then mount the squashfs and execute switch_root(8)
to move it to /. An squashfs-based root will be read-only.

/src/build and /src/log are ignored. Beside from that, this script is
not Sabotage specific and may be used on other Linux distributions.
EOF
}

[ -z "$2" ] && help >/dev/stderr && exit 1
[ "$1" = "-h" ] && help && exit

# The squashfs will be mounted read-only in the live system.
# Create secondary source for mount stubs like /dev or /proc.
rootdir="$(mktemp -d)"

# Get paths of top-level directories
# Skip mount stubs and create them in $rootdir instead
primary="$(find /tmp/sabotage -maxdepth 1 -mindepth 1|while read dir; do
	case "$dir" in
		*boot|*dev|*proc|*sys)
			mkdir "$rootdir/$(basename "$dir")"
			;;
		*)
			echo $dir
			;;
	esac
done)"

# Get paths of mount stubs from $rootdir
stubs="$(find $rootdir -maxdepth 1 -mindepth 1)"

# Do the work!
mksquashfs $primary $stubs "$2" -e src/build src/log
r=$?

# Important: remove the tmpdir
rm -rf "$rootdir"

# Return the exit code from mksquashfs
exit $r