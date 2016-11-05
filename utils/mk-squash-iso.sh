#!/bin/sh
help() {
	cat <<EOF
mk-squash-iso.sh [options]
	Turns an sabotage rootfs into an bootable iso.
	This requires an working isolinux installation on <rootfs>/boot.

	-o <file>
		Set the output file. Existing files will be overwritten
		without asking. The file will be an iso image.

	-l <label>
		Define a custom ISO9660 disk label.

	-r <dir>
		Set the source rootfs. The rootfs itself will not be changed.

	-t
		Exclude tarballs directory.

	-d
		Dry run: Only check config and stuff

	<rootfs>/boot will be copied to the new isofs root and completed by
	an squashfs containing the rest of the system. The initramfs will be
	responsible for finding and mounting that squashfs.

	If you use this, prepare to have OVERLAY_FS enabled on the kernel
	you put into <rootfs>boot/, otherwise your cdrom system will be
	read-only.

	If you want to create an own isolinux.cfg, you can instruct the
	initramfs to load the squashfs with the following kernel options:

		boot=LABEL="FOOBAR" root=/boot/squashfs.img rootfsflags=loop

	Replace FOOBAR with the value you also specified with -l
EOF
}

warn() {
	echo "WARN: $@"
}

fail() {
	echo "FAIL: $@"
	rm -rf $ISOROOT
	rm -rf $FAKEROOT
	exit 1
}

EXCLUDE="src/build src/log"
DRY="false"

while [ -n "$1" ]; do
	case "$1" in
		'-o')
			OUTFILE=$2
			shift 2
			;;
		'-l')
			DISKID=$2
			shift 2
			;;
		'-r')
			R=$2
			shift 2
			;;
		'-t')
			EXCLUDE="$EXCLUDE src/tarballs"
			shift 1
			;;
		'-d')
			DRY="true"
			shift 1
			;;
	esac
done

[ -z "$R" ] && [ -f config ] && . ./config
[ -d "$R" ] || fail "$R does not exist or not a directory"
[ -z "$DISKID" ] && DISKID="sabotage-$ARCH-`date +%Y%m%d`"
[ -z "$OUTFILE" ] && OUTFILE="$DISKID.iso"

# Check for prerequisite commands
type mksquashfs >/dev/null \
	|| fail "mksquashfs not found, try butch install squashfs-tools"

type mkisofs >/dev/null \
	|| fail "mkisofs not found, try butch install xorriso"

# The tempdir that will become the ISO root and the new /boot
ISOROOT=$(mktemp -d)
cp -r $R/boot/* $ISOROOT

# Create directory stubs for the squashfs
# Those are required as mountpoints for their actual filesystems
FAKEROOT=$(mktemp -d)
mkdir $FAKEROOT/boot $FAKEROOT/proc $FAKEROOT/sys $FAKEROOT/dev $FAKEROOT/tmp $FAKEROOT/mnt

if ! [ -f "$ISOROOT/isolinux.cfg" ]; then 
	warn "/boot/isolinux.cfg not found, generating default config"
	cat <<EOF > $ISOROOT/isolinux.cfg
PROMPT 1
TIMEOUT 100
DEFAULT sabotage

LABEL ro
		MENU LABEL Boot with read-only rootfs
        KERNEL vmlinuz
		INITRD initrd.img
        APPEND boot=LABEL="$DISKID" root=/boot/squashfs.img rootfsflags=loop

LABEL sabotage
		MENU LABEL Boot with RAM overlayfs
        KERNEL vmlinuz
		INITRD initrd.img
        APPEND boot=LABEL="$DISKID" root=/boot/squashfs.img rootfsflags=loop overlayfstype=tmpfs

LABEL rescue
		MENU LABEL Boot to initramfs
        KERNEL vmlinuz
		INITRD initrd.img
        APPEND boot=LABEL="$DISKID" root=/boot/squashfs.img rootfsflags=loop rescue
EOF
fi

# Do some sort of validation
cat $ISOROOT/isolinux.cfg|grep '^\s*\(KERNEL\|INITRD\)'|awk '{print($2)}' \
	|sort -u|while read file; do
	[ -f "$ISOROOT/$file" ] \
		|| warn "/boot/$file not found, but referenced by isolinux.cfg"
done

# At least some config has to be available
[ -f "$ISOROOT/isolinux.cfg" ] \
	|| fail 'isolinux.cfg not present, iso will not be bootable'

# Check for isolinux.bin ready
[ -f "$ISOROOT/isolinux.bin" ] || fail "isolinux.bin required, but not found"

# Detect syslinux version
isoversion=$(strings "$ISOROOT/isolinux.bin"|grep ISOLINUX)
[ -z "$isoversion" ] && fail "ISOLINUX version could not be detected"
echo "INFO: $isoversion detected" 

# Check for ldlinux.c32 ready if required
if echo $isoversion|awk '{if($2<5) exit 1;}'; then
	[ -f "$ISOROOT/ldlinux.c32" ] || fail "ldlinux.c32 required, but not found"
fi

$DRY && fail "Cancelled by -d"

# Only add selected directories from the rootfs
# Add stubs from the tmpdir so they can at least act as mount point
mksquashfs "$R/bin" "$R/etc" "$R/home" "$R/include" "$R/lib" "$R/libexec" \
	"$R/opt" "$R/root" "$R/sbin" "$R/share" "$R/src" "$R/srv" "$R/usr" \
	"$R/var" $FAKEROOT/* "$ISOROOT/squashfs.img" -e $EXCLUDE \
	|| fail "mksquashfs failed with exit code $?"

# Build the ISO. See the ISOLINUX install instructions on their website
mkisofs -o "$OUTFILE" -b isolinux.bin -c boot.cat -V "$DISKID" -no-emul-boot \
	-iso-level 2 -boot-load-size 4 -boot-info-table "$ISOROOT" \
	|| fail "mkisofs failed with exit code $?"

rm -rf "$ISOROOT"
rm -rf "$FAKEROOT"

echo "Result saved at $OUTFILE"

