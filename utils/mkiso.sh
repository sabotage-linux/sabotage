#!/bin/sh
set +e

help() {
	cat <<EOF
Syntax: mkiso.sh [-s] <path to system root> <destination filename>

Create an bootable ISO file from an existing root file system.

Per default the system is compressed as cpio archive and will be loaded into
RAM on startup. If you specify the -s switch, the system will be stored as
squashfs which will be mounted directly from the disk. While this will save
RAM, it will result in an read-only /.

This script requires a working mkisofs and syslinux installation on the host.
EOF
}

warn() {
	echo "WARN: $@"
}

fail() {
	echo "FAIL: $@"
	rm -rf "$root"
	exit 1
}

systype="-i"

# This will instruct mksysboot to pack the system as squashfs, not as cpio
if [ "$1" = "-s" ]; then
	systype="-s"
	shift 1
fi

[ -z "$2" ] && help >/dev/stderr && exit 1
[ "$1" = "-h" ] && help && exit

hash mksisofs >/dev/null 2>&1 || alias mkisofs='xorriso -as mkisofs'

cdir="$(dirname "$0")"

root="$(mktemp -d)"
volid="sabotage"

isopath=$(find /usr/lib /usr/share|grep -E 'isolinux.bin$'|head -n 1)

# Copy isolinux.bin (ISO-specific part of SYSLINUX)
[ -f "$root/isolinux.bin" ] \
	|| (cp "$isopath" "$root/isolinux.bin" && echo "INFO: Using $isopath for ISOLINUX install")\
	|| fail "isolinux.bin required, but not found"

# Create syslinux installation in $root
$cdir/mksysboot.sh "$root" -b "boot=LABEL=$volid" $systype "$1" \
	|| fail "unable to create SYSLINUX installation"

echo "Volume ID will be '$volid'"

# Create the ISO file
# Reference: http://www.syslinux.org/wiki/index.php?title=ISOLINUX
mkisofs -o "$2" -b isolinux.bin -c boot.cat -V "$volid" -no-emul-boot \
	-iso-level 2 -boot-load-size 4 -boot-info-table "$root" \
	|| fail "unable to create ISO file"

# Remove tmpdir, but exit with mkisofs's return code
r=$?
rm -rf "$root"
exit $?