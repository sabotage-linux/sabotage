#!/bin/sh
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
for i ; do cmdline="$cmdline $(quote "$i")" ; done
printf "%s" "$cmdline"
}


run_echo() {
	local cmdline=$(quote_args $@)
	printf "%s\n" "$cmdline"
	"$@"
}

isemptydir() {
	if [ $(ls "$1" | wc -l) = "0" ] ; then true ; else false ; fi
}

mountdir=

cpio --help 2>&1 > /dev/null || die "cpio is needed to create hard disk image"
[ -z "$UID" ] && UID=`id -u`
[ "$UID" = "0" ] || die "must be root"

imagefile="$1"
[ -z "$imagefile" ] && usage

contents="$2"
[ -z "$contents" ] && usage
[ ! -f "$contents" ] && [ ! -d "$contents" ] && die "failed to access $contents"
[ -d "$contents" ] && [ ! -d "$contents"/src ] && die "$contents does not contain a valid directory layout"
if ! isemptydir "$contents/proc" || ! isemptydir "$contents/sys" || ! isemptydir "$contents/dev" ; then
	die "$contents was not properly unmounted! (check sys/ dev/ proc/)"
fi
[ ! -f "$contents"/boot/vmlinuz ] && die "$contents does not have a kernel image"
[ ! -x "$contents"/bin/extlinux ] && die 'extlinux must be in $contents (try installing extlinux on the target)'
[ ! -x "$contents"/bin/mksquashfs ] && die 'mksquashfs must be in $contents (try installing squashfs-tools on the target)'
tempcnts="$(mktemp -d)"
cp -a "$contents"/* "$tempcnts"
contents="$tempcnts"

imagesize="$3"
[ -z "$imagesize" ] && usage

check_opts $@
[ "$copy_tarballs" = "1" ] && [ -z "$C" ] && die "--copy_tarballs needs C to be set. consider running 'source config'"

for mbr_bin in mbr.bin /usr/lib/syslinux/mbr.bin /usr/share/syslinux/mbr.bin /usr/lib/syslinux/bios/mbr.bin
	do [ -f "$mbr_bin" ] && break ; done

[ -z "$mbr_bin" ] && die 'Could not find mbr.bin'

echo_bold "0) rm the image file"
[ -f "$imagefile" ] && rm -f "$imagefile"

echo_bold "1) make the image file"
dd if=/dev/zero of="$imagefile" bs=1 count=0 seek="$imagesize" || die "Failed to create $imagefile"

echo_bold "2) fdisk"

bytes_per_sector=512
sectors_per_track=63
heads=255
#tracks/cylinder

# partition (/), starts on sector 2048
part_start_sector=2048

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
part_start=$(($bytes_per_sector * $part_start_sector))

echo fdisk -H "$heads" -S "$sectors_per_track" -b "$bytes_per_sector" $need_u_flag "$imagefile"
fdisk -H "$heads" -S "$sectors_per_track" -b "$bytes_per_sector" $need_u_flag "$imagefile" << EOF
n
p
1
$part_start_sector

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

run_echo losetup -o $part_start "$loopdev" "$imagefile" || die 'Failed to losetup for /'

mkdir -p "$mountdir" || die_unloop 'Failed to create '"$mountdir"
mkfs.ext4 -O extents "$loopdev" || die_unloop 'Failed to mkfs.ext4 loop for /'
mount "$loopdev" "$mountdir" || die_unloop 'Failed to mount loop for /'
mkdir "$mountdir"

if [ -d "$contents" ] ; then
	cp -a "$contents"/boot/* "$mountdir" || die_unmount 'Failed to copy boot'
else
	tar -C "$mountdir" -xf "$contents" boot || die_unmount 'Failed to extract boot'
fi

extcfg() {
  kernel="$1"
  fs="$2"
  echo "LABEL $kernel - $fs"
  echo "      KERNEL $kernel"
  echo "      INITRD /default.igz"
  echo "      APPEND boot=/dev/sda1 vga=ask sqsh_root=$fs"
  echo "LABEL $kernel - $fs rescue"
  echo "      KERNEL $kernel"
  echo "      INITRD /default.igz"
  echo "      APPEND boot=/dev/sda1 sqsh_root=$fs"

}
"$contents"/bin/extlinux -i "$mountdir" || die_unmount 'Failed to install extlinux'
(
  echo "PROMPT 1"
  echo "TIMEOUT 100"
  echo "DEFAULT /vmlinuz - /root.sqsh.img"
  extcfg "/vmlinuz" "/root.sqsh.img"
) > "$mountdir"/extlinux.conf

sync
echo_bold "copying contents, this will take a while"
if [ ! -d "$contents" ]; then
	time tar -C "$mountdir" -zxf "$contents" || die_unmount 'Failed to extract /'
fi

echo_bold ' 6) applying root perms'
$MYDIR/root-perms.sh "$contents"

echo_bold ' 7) creating squash'
if [ "$clear_builds" = "1" ] ; then
  buildexclude='src/build/**'
fi
if [ "$copy_tarballs" != "1" ] ; then
  tarexclude='src/tarballs/**'
fi
rm "$contents"/root.sqsh.img
chroot "$contents" mksquashfs / /root.sqsh.img -wildcards -e '**.sqsh.img' 'proc/**' 'sys/**' 'dev/**' 'boot/**' $tarexclude $buildexclude

time cp "$contents"/root.sqsh.img "$mountdir"/

echo_bold ' 8) creating initramfs'
(
  cd "$mountdir"
  mkdir -p initramfs/bin
  cp "$contents"/opt/busybox/bin/busybox initramfs/bin
  ln -s busybox initramfs/bin/sh
  cp "$contents"/src/KEEP/initramfs.init initramfs/init
  chmod +x initramfs/init
  mkdir initramfs/boot initramfs/newroot initramfs/sbin initramfs/proc initramfs/sys
  cd initramfs
  find . | cpio -H newc -o | gzip > ../default.igz
  cd ..
  rm -r initramfs
)

echo_bold ' 9) cleaning up'

chown -R root:root "$mountdir"
chmod -R '440' "$mountdir"
sync
umount "$mountdir" || die_unloop 'Failed to unmount /'
sync
losetup -d "$loopdev"

# cleanup
rmdir "$mountdir" || die "Failed to remove $mountdir"
rm -r "$tempcnts"
echo_bold 'Done.'
