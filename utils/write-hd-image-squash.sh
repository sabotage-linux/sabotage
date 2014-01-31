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
	umount "$contents"/sys "$contents"/proc "$contents"/dev
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
[ ! -x "$contents"/bin/syslinux ] && die 'syslinux must be in $contents (try installing syslinux6 on the target)'
[ ! -x "$contents"/bin/mksquashfs ] && die 'mksquashfs must be in $contents (try installing squashfs-tools on the target)'
[ ! -x "$contents"/bin/mcopy ] && die 'mcopy not found in $contents (try installing mtools)'
[ ! -x "$contents"/bin/mkfs.vfat ] && die 'no mkfs.vfat, install dosfstools on target'

imagesize="$3"
[ -z "$imagesize" ] && usage

check_opts $@
[ "$copy_tarballs" = "1" ] && [ -z "$C" ] && die "--copy_tarballs needs C to be set. consider running 'source config'"

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

t
b

a
1
w
EOF

echo_bold '3) copy mbr'
for mbr_bin in mbr.bin "$contents"/lib/syslinux/bios/mbr.bin "$contents"/lib/syslinux/mbr.bin
        do [ -f "$mbr_bin" ] && break ; done
dd conv=notrunc if="$mbr_bin" of="$imagefile" || die 'Failed to set up MBR'

echo_bold '4) /boot'
loopdev=`losetup -f`
mountdir="/tmp/mnt.$$"

echo_bold "info: mounting $imagefile as $loopdev on $mountdir"

run_echo losetup -o $part_start "$loopdev" "$imagefile" || die 'Failed to losetup for /'

mkdir -p "$mountdir" || die_unloop 'Failed to create '"$mountdir"

mount --bind /dev "$contents/dev"
mount -t proc proc "$contents/proc"
mount -t sysfs sys "$contents/sys"
chroot "$contents" mkfs.vfat "$loopdev" || die_unloop 'Failed to mkfs.vfat loop for /'
sync
umount "$contents/dev" "$contents/proc" "$contents/sys"

mount "$loopdev" "$mountdir" || die_unloop 'Failed to mount loop for /'
mkdir "$mountdir"

if [ -d "$contents" ] ; then
	cp "$contents"/boot/* "$mountdir" || die_unmount 'Failed to copy boot'
else
	tar -C "$mountdir" -xf "$contents" boot || die_unmount 'Failed to extract boot'
fi

extcfg() {
  kernel="$1"
  fs="$2"
  echo "LABEL $kernel - $fs"
  echo "      MENU LABEL $kernel - $fs"
  echo "      KERNEL $kernel"
  echo "      INITRD /default.igz"
  echo "      APPEND boot=/dev/sda1 sqsh_root=$fs"
}

rm "$mountdir"/extlinux.conf
mkdir -p "$mountdir"/EFI/BOOT
menumods="menu.c32 libutil.c32"
for i in ldlinux.c32 $menumods; do
  cp "$contents"/lib/syslinux/bios/$i "$mountdir"/ || die_unmount 'Failed to install '$i
done
if [ -d "$contents"/lib/syslinux/efi64 ]; then
 for i in ldlinux.e64 $menumods; do
    cp "$contents"/lib/syslinux/efi64/$i "$mountdir"/EFI/BOOT || die_unmount 'Failed to install '$i
  done
  cp "$contents"/lib/syslinux/efi64/syslinux.efi "$mountdir"/EFI/BOOT/bootx64.efi
elif [ -d "$contents"/lib/syslinux/efi32 ]; then
 for i in ldlinux.e32 $menumods; do
    cp "$contents"/lib/syslinux/efi32/$i "$mountdir"/EFI/BOOT || die_unmount 'Failed to install '$i
  done
  cp "$contents"/lib/syslinux/efi32/syslinux.efi "$mountdir"/EFI/BOOT/bootia32.efi
fi

(
  echo "UI menu.c32"
  echo "PROMPT 0"
  echo "TIMEOUT 100"
  echo "DEFAULT /vmlinuz - /root.sqsh.img"
  extcfg "/vmlinuz" "/root.sqsh.img"
) > "$mountdir"/syslinux.cfg
echo "INCLUDE /syslinux.cfg" > "$mountdir"/EFI/BOOT/syslinux.cfg
mount --bind /dev "$contents/dev"
mount -t proc proc "$contents/proc"
mount -t sysfs sys "$contents/sys"
chroot "$contents" syslinux -i $loopdev || die_unmount 'Failed to install syslinux'
umount "$contents/dev" "$contents/proc" "$contents/sys"

sync

echo_bold ' 6) applying root perms'
$MYDIR/root-perms.sh "$contents"

echo_bold ' 7) creating squash'
mount --bind /dev "$contents"/dev
mount -t proc proc "$contents"/proc
mount -t sysfs sys "$contents"/sys
chroot "$contents" /bin/sh << EOF || die_unmount 'Failed to run service prereqs'
for i in /etc/service/*/run; do
  [ ! -e "\$(dirname \$i)"/down ] && \$i --prereqs || echo "\$i --prereqs failed"
done
EOF
umount "$contents"/dev "$contents"/proc "$contents"/sys

if [ "$clear_builds" = "1" ] ; then
  buildexclude='src/build/**'
fi
if [ "$copy_tarballs" != "1" ] ; then
  tarexclude='src/tarballs/**'
fi
rm "$contents"/root.sqsh.img

mkdir -p "$contents"/var/run "$contents"/rw
chroot "$contents" mksquashfs / /root.sqsh.img -p 'bin/su m 4755 root root' -wildcards -e '**.sqsh.img' 'proc/**' 'sys/**' 'dev/**' 'boot/**' $tarexclude $buildexclude

time cp "$contents"/root.sqsh.img "$mountdir"/

echo_bold ' 8) creating initramfs'

  initramfstmp=$(mktemp -d)
  cd "$initramfstmp"
  mkdir -p initramfs/bin initramfs/boot initramfs/newroot initramfs/sbin initramfs/proc initramfs/sys initramfs/etc
  cp "$contents"/opt/busybox/bin/busybox initramfs/bin
  ln -s busybox initramfs/bin/sh
  cp -L "$contents"/bin/fsck* initramfs/bin
  cp "$contents"/src/KEEP/initramfs.fstab initramfs/etc/fstab
  cp "$contents"/src/KEEP/initramfs.init initramfs/init
  chmod +x initramfs/init
  cp -a "$initramfstmp" "$contents"/"$initramfstmp"
  chroot "$contents" sh -c "cd $initramfstmp/initramfs; find . | cpio -H newc -o | gzip > $initramfstmp/default.igz"
  cp "$contents"/"$initramfstmp"/default.igz "$mountdir"
  cd
  rm -r "$initramfstmp" "$contents"/"$initramfstmp"

echo_bold ' 9) cleaning up'

chown -R root:root "$mountdir"
chmod -R '440' "$mountdir"
sync
umount "$mountdir" || die_unloop 'Failed to unmount /'
sync
losetup -d "$loopdev"

# cleanup
rmdir "$mountdir" || die "Failed to remove $mountdir"
echo_bold 'Done.'
