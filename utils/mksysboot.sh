#!/bin/sh
set +e

help () {
    cat <<EOF
Syntax: mksysboot.sh <target directory> <options>

mksysboot will create an syslinux based boot directory. This is the directory
that will be /boot on a disk-based install or the content of an bootable ISO.

The following options are implemented:
  -b <string>   Specify a string to be included in the bootparams.
                This feature is useful to tell installations how their boot
                partition is named, eg -b "boot=/dev/sr0"

  -i <path>     Compress a system as cpio/initramfs and include it into the
                target.

  -s <path>     Compress a system as squashfs and include it into the target

The options are parsed in order and may be used several times to overwrite the
previous value. Multiple systems are supported.
EOF
}

warn() {
	echo "WARN: $@"
}

fail() {
	echo "FAIL: $@"
	rm -rf "$bootdir"
	exit 1
}

find_system_name() {
	cd "$1"
	id="$(cat etc/os-release 2>/dev/null|grep '^ID'|cut '-d=' -f2|sed 's/"//g')"
	[ -z "$id" ] && id="$(cat etc/hostname 2>/dev/null)"
	[ -z "$id" ] && id="$(basename "$1"|sed 's,/,,g')"
	echo "$id"
}

# Copy foreign /boot to target
# Skip if paths are equal
copy_kernels() {
	src="$(readlink -f "$1")"
	if [ "$src" = "$2" ]; then
		[ -n "$prefix" ] && fail "The target directory is part of an source system, which MUST BE the first system referenced in the source options."
		# Do nothing because stuff is already in place
	else
		ls "$src"|while read name; do
			cp -r "$1/$name" "$2/$3$name"
		done
	fi
}

# Create syslinux config from directory + prefix
create_config() {
	ls "$1"|grep "^${2}vmlinu"|sort -rn|while read kernel; do
		suffix="$(printf "%s\n" "$kernel"|sed "s/^${2}vmlinuz//")"
		id="$2$3$suffix"

		# Find an initramfs
		initrd="$4"
		[ "$initrd" = "auto" ] && initrd="$(ls "$1"|grep "^$prefix"|grep -v rootfs|grep -E '^init|cpio'|grep "$version"|head -n 1)"
		[ -z "$initrd" ] && initrd="$(ls "$1"|grep "^$prefix"|grep -v rootfs|grep -E '^init|cpio'|head -n 1)"

		echo "LABEL $id"
		echo "	KERNEL $kernel"
		[ -n "$initrd" ] && echo "	INITRD $initrd"
		[ -n "$5" ] && echo "	APPEND $5"
		echo ""
	done
}

install_syslinux_component() {
	cpath=$(find /lib /usr/lib /usr/share|grep -v efi|grep -E "/$1\$"|head -n 1)
	[ -f "$bootdir/$1" ] \
		|| (cp "$cpath" "$bootdir/$1" && echo "INFO: Using $cpath $2") \
		|| fail "syslinux component $1 required, but not found"

	# fuck those dependencies :'( this is far from complete, but covers the two menus
	case "$1" in
		menu.c32)
			install_syslinux_component "libutil.c32"
			;;
		vesamenu.c32)
			install_syslinux_component "libutil.c32"
			install_syslinux_component "libcom32.c32"
			;;
	esac
}

cdir="$(dirname "$0")"
[ -z "$1" ] && help >/dev/stderr && exit 1

bootdir="$(readlink -f "$1")"
mkdir -p "$bootdir"
shift 1

first=true

# "syslinux.cfg" works for all boot methods for newer SYSLINUX installs.
cfg="syslinux.cfg"

install_syslinux_component "ldlinux.c32"

echo "PROMPT 1" > "$bootdir/$cfg"
echo "TIMEOUT 50" >> "$bootdir/$cfg"
# Note: this will be changed later with sed
echo "DEFAULT default" >> "$bootdir/$cfg"
echo "" >> "$bootdir/$cfg"

while [ -n "$1" ]; do
	case "$1" in
	'-b')
		bootparams="$2"
		shift 2
		;;
	'-i') # Pack $2 as cpio into the syslinux directory
		id="$(find_system_name "$2")"
		prefix="$id-"
		$first && prefix="" && first=false
		$cdir/mkcpio.sh "$2" "$bootdir/${prefix}rootfs.cpio"
		copy_kernels "$2/boot" "$bootdir" "$prefix"
		create_config "$bootdir" "$prefix" "ram" "${prefix}rootfs.cpio" "${bootparams}" "$id" >> "$bootdir/$cfg"
		shift 2
		;;
	'-s') # Pack $2 as squashfs into the syslinux directory
		id="$(find_system_name "$2")"
		prefix="$id-"
		$first && prefix="" && first=false
		$cdir/mksquashfs.sh "$2" "$bootdir/${prefix}squashfs.img"
		copy_kernels "$2/boot" "$bootdir" "$prefix"
		create_config "$bootdir" "$prefix" "overlay" "auto" "${bootparams} root=/boot/${prefix}squashfs.img rootfsflags=loop overlayfstype=tmpfs" "$id" >> "$bootdir/$cfg"
		create_config "$bootdir" "$prefix" "squash" "auto" "${bootparams} root=/boot/${prefix}squashfs.img rootfsflags=loop" "$id" >> "$bootdir/$cfg"
		shift 2
		;;
	'-h'|'--help')
		help;
		exit 0
		;;
	*)
		help >&2
		exit 1
		;;
	esac
done

# Do some sort of validation on syslinux.cfg
cat $bootdir/$cfg|grep '^\s*\(KERNEL\|INITRD\|CONFIG\|UI\)'| \
	awk '{print($2)}'|sort -u|while read file; do
	printf "%s\n" "$file"|grep -q '\.c32$' && install_syslinux_component "$file" "for use by $cfg"
	[ -f "$bootdir/$file" ] \
		|| warn "$file not found, but referenced by $cfg"
done

# Take the firstmost entry as default
default="$(grep '^LABEL' $bootdir/$cfg|head -n 1|cut '-d ' -f2)"
sed -i "s,^DEFAULT .*,DEFAULT $default," "$bootdir/$cfg"
