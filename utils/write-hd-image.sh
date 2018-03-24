#!/bin/sh
# use: write-hd-image.sh <img file> <root directory or tarball> <size> [--clear-builds] [--copy-tarballs]
# "--clear-builds" clears /src/build
# "`--copy-tarballs" will copy tarballs from $C
# "size" will be passed to dd, so you can use whatever value dd supports. (i.e. 8G)
# the resulting raw image may be written to media via dd or converted to various VM drive formats
 
MYDIR=$(dirname "$(readlink -f "$0")")

echo_bold() {
	tput bold
	echo $@
	tput sgr0
}

usage() {
	echo_bold "Usage: $0 <img file> <directory or tarball of content> <img size> [options]"
	echo "options: --clear-builds --copy-tarballs"
	echo
	echo "--clear-builds will remove stuff in /src/build (butch 0.0.8+ build directory)"
	echo '--copy-tarballs will copy tarballs from directory pointed to by "C" env var'
	echo
	echo "<img size> will be passed directly to dd, so you can use whatever value dd supports, i.e. 8G"
	exit 1
}

die() {
	echo "$1"
	[ -d "$mountdir" ] && rmdir "$mountdir"
	exit 1
}

die_unloop() {
	sync
	losetup -d "$loopdev"
	die "$1"
}

die_unmount() {
	umount "$mountdir" || die_unloop 'Failed to unmount /boot'
	die_unloop "$1"
}

check_opts() {
	while [ ! -z "$1" ] ; do
		case $1 in
			--clear-builds)
				echo "clear_builds selected"
				clear_builds=1;;
			--copy-tarballs)
				echo "copy_tarballs selected"
				copy_tarballs=1;;
		esac
		shift
	done
}

quote () {
tr '\n' ' ' <<EOF | grep '^[-[:alnum:]_=,./:]* $' >/dev/null 2>&1 && { echo "$1" ; return 0 ; }
$1
EOF
printf %s\\n "$1" | sed -e "s/'/'\\\\''/g" -e "1s/^/'/" -e "\$s/\$/'/" -e "s#^'\([-[:alnum:]_,./:]*\)=\(.*\)\$#\1='\2#"
}

quote_args() {
local cmdline=
for i ; do cmdline="$cmdline $(quote $i)" ; done
printf "%s" "$cmdline"
}


run_echo() {
	local cmdline="$(quote_args $@)"
	printf "%s\n" "$cmdline"
	"$@"
}

isemptydir() {
	if [ $(ls "$1" | wc -l) = "0" ] ; then true ; else false ; fi
}

mountdir=

imagefile="$1"
[ -z "$imagefile" ] && usage

contents="$2"
[ -z "$contents" ] && usage
[ ! -f "$contents" ] && [ ! -d "$contents" ] && die "failed to access $contents"
[ -d "$contents" ] && [ ! -d "$contents"/src ] && die "$contents does not contain a valid directory layout"
if ! isemptydir "$contents/proc" || ! isemptydir "$contents/sys" || ! isemptydir "$contents/dev" ; then
	die "$contents was not properly unmounted! (check sys/ dev/ proc/)"
fi
[ ! -f "$contents"/boot/vmlinuz ] && \
	echo "warning: $contents does not seem to have a kernel image"

imagesize="$3"
[ -z "$imagesize" ] && usage

check_opts $@
[ "$copy_tarballs" = "1" ] && [ -z "$C" ] && die "--copy_tarballs needs C to be set. consider running 'source config'"

for mbr_bin in mbr.bin /usr/lib/syslinux/mbr.bin /usr/share/syslinux/mbr.bin 
	do [ -f "$mbr_bin" ] && break ; done

[ -z "$mbr_bin" ] && die 'Could not find mbr.bin'

[ -z "$UID" ] && UID=`id -u`
[ "$UID" = "0" ] || die "must be root"

losetup --help 2>&1 | grep [-]-sizelimit > /dev/null \
  || die "losetup does not support --sizelimit. maybe try building util-linux"

which extlinux 2>&1 > /dev/null || die 'extlinux must be in PATH (try installing syslinux)'

echo_bold "0) rm the image file"
[ -f "$imagefile" ] && rm -f "$imagefile"

echo_bold "1) make the image file"
dd if=/dev/zero of="$imagefile" bs=1 count=0 seek="$imagesize" || die "Failed to create $imagefile"

echo_bold "2) fdisk"

bytes_per_sector=512
sectors_per_track=63
heads=255
#tracks/cylinder

# first partition (/boot), starts on sector 2048 and is 100 MB
part1_start_sector=2048
part1_size_mb=100

# second partition starts at $part1_start_sector + ($part1_size_mb * 1024 * (1024/512))
part2_start_sector=$(($part1_start_sector + ($part1_size_mb * 1024 * 1024 / $bytes_per_sector)))

# ancient fdisk 2.17 (as used by debian 6) does not calculate cylinders automatically...
imagesize_in_bytes=`wc -c $imagefile |  cut -d ' ' -f 1`

cylinders=$(($imagesize_in_bytes / ($heads * $sectors_per_track * $bytes_per_sector)))

# n - new partition
# p - primary partition
# part. number
# 2048 : first sector (this is required for images > a couple GB)
# +100M: size of first partition
# n - new partition
# part. number
# RETURN : use default sector
# RETURN : use default size
# a - toggle bootable flag
# part. number
# w - write

# byte positions
part1_start=$(($bytes_per_sector * $part1_start_sector))
part1_size=$(($part1_size_mb * 1024 * 1024))

# test if we're using the ancient version, it can't deal with -u=sectors flag
# additionally, sending "u" to it as a keystroke will turn into sectors mode, while
# the newer versions will turn into deprecated cylinder mode.
# even worse, the old version will allocate one sector too much.
echo q | fdisk -u=sectors "$imagefile" 2>/dev/null || olde_shit=1
need_u_flag=
if [ "$olde_shit" = "1" ] ; then
	echo "ancient fdisk version detected, passing -u"
	need_u_flag="-u"
	part2_start_sector=$(($part2_start_sector + 2))
	part1_size=$(($part1_size + (2 * $bytes_per_sector)))
fi

# byte pos
part2_start=$(($part1_start + $part1_size))

echo fdisk -C "$cylinders" -H "$heads" -S "$sectors_per_track" -b "$bytes_per_sector" $need_u_flag "$imagefile"
fdisk -C "$cylinders" -H "$heads" -S "$sectors_per_track" -b "$bytes_per_sector" $need_u_flag "$imagefile" << EOF
n
p
1
$part1_start_sector
+${part1_size_mb}M
n
p
2
$part2_start_sector

a
1
w
EOF

echo_bold '3) copy mbr'
dd conv=notrunc if="$mbr_bin" of="$imagefile" || die 'Failed to set up MBR'

echo_bold '4) /boot'
loopdev=`losetup -f`
mountdir="/tmp/mnt.$$"

echo_bold "info: mounting $imagefile as $loopdev on $mountdir"

run_echo losetup -o $part1_start --sizelimit $part1_size "$loopdev" "$imagefile" || die 'Failed to losetup for /boot'

mkdir -p "$mountdir" || die_unloop 'Failed to create '"$mountdir"
mkfs.ext3 "$loopdev" || die_unloop 'Failed to mkfs.ext3 loop for /boot'
mount "$loopdev" "$mountdir" || die_unloop 'Failed to mount loop for /boot'

if [ -d "$contents" ] ; then
	cp -a "$contents"/boot/* "$mountdir"/ || die_unmount 'Failed to copy boot'
else
	tar -C "$mountdir" -xf "$contents" boot || die_unmount 'Failed to extract boot'
	mv "$mountdir"/boot/* "$mountdir"/ || die_unmount 'Failed to move /boot content to root of boot partition'
	rmdir "$mountdir"/boot
fi
sed -i 's/sda1/sda2/g' "$mountdir"/extlinux.conf || die_unmount 'Failed to reconfigure extlinux.conf'
extlinux -i "$mountdir"/ || die_unmount 'Failed to install extlinux'
umount "$mountdir" || die_unloop 'Failed to unmount /boot'
sync
losetup -d "$loopdev"

echo_bold ' 5) /'
loopdev=`losetup -f`
run_echo losetup -o $part2_start "$loopdev" "$imagefile" || die 'Failed to losetup for /'
mkfs.ext4 "$loopdev" || die_unloop 'Failed to mkfs.ext4 loop for /'
mount "$loopdev" "$mountdir" || die_unloop 'Failed to mount loop for /'

echo_bold "copying contents, this will take a while"
if [ -d "$contents" ]
then
	if [ "$clear_builds" = "1" ] ; then
		echo -ne "clearing builds..."
		[ -d "$contents/src/build" ] && rm -rf "$contents/src/build"/*
		echo "done"
	fi
	if [ "$copy_tarballs" = "1" ] ; then
		echo -ne "copying tarballs..."
		mkdir -p "$mountdir/src/tarballs/"
		cp -f "$C/"* "$mountdir/src/tarballs/"
		echo "done"
	fi

	time cp -a "$contents"/* "$mountdir"/ || die_unmount 'Failed to copy /'
	ls_contents=`ls "$mountdir/"`
	printf "%s\n" "$ls_contents"
else
	time tar -C "$mountdir" -zxf "$contents" || die_unmount 'Failed to extract /'
fi
rm -f "$mountdir"/boot/*
echo '/dev/sda1 /boot ext3 defaults 0 0' >> "$mountdir"/etc/fstab || die_unmount 'Failed to extend fstab'

echo_bold ' 6) applying root perms'
$MYDIR/root-perms.sh "$mountdir"

echo_bold ' 7) cleaning up'

umount "$mountdir" || die_unloop 'Failed to unmount /'
sync
losetup -d "$loopdev"

# cleanup
rmdir "$mountdir" || die "Failed to remove $mountdir"

echo_bold 'Done.'

