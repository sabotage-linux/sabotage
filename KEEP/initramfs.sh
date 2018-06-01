#!/bin/busybox sh

rescue() {
	# If panic parameter is set, just exit. This will
	# exit PID 1 and cause a kernel panic
	[ -n "$panic" ] && exit 1

	# Silence the kernel
	echo 0 > /proc/sys/kernel/printk
	echo "$@"
	echo "Exit the shell to continue booting"
	PS1="(initramfs) \w\$ " /bin/sh
}

# Wrapper around findfs to allow values like "tmpfs"
findblk() {
	dev="$1"
	case "$dev" in
		LABEL=*|UUID=*) dev=$(findfs "$dev");;
		'') dev="none"
	esac
	echo "$dev"
}

export PATH=/bin
/bin/busybox --install -s /bin

# Setup "those" directories
mkdir -p /proc /sys /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Set default values
init=/bin/init root=/dev/sda1

# Import kernel options as local variables
eval `cat /proc/cmdline|grep -o -E '[a-zA-Z_]+[a-zA-Z0-9_]*(|=[^ "]*|=\S*"[^"]*"\S*)' \
	|awk '/=/{print $0;next;}{print $0 "=default"}'`

# Mount boot partition (required for CD boot)
if [ -n "$boot" ]; then
	mkdir /boot
	mount "$boot" /boot
fi

# Load keymap
if [ -n "$kmap" ]; then
	loadkmap < /share/kmap/$kmap.kmap
fi

[ -n "$cryptsetup" ] || cryptsetup="$cryptdevice"

# Try to mount the cryptdevice
if [ -n "$cryptsetup" ]; then
	# Silence the kernel
	echo 0 > /proc/sys/kernel/printk
	cryptdev=$(printf "%s\n" "$cryptsetup" | cut -d: -f1)
	mapper=$(printf "%s\n" "$cryptsetup" | cut -d: -f2)
	cryptsetup luksOpen "`findblk $cryptdev`" "$mapper" \
		|| rescue "cryptsetup failed with code $?"
fi

# Scan around for lvm devices, see if you can find any
if [ -n "$lvm" ]; then
	lvm vgscan
	lvm vgchange -a y
fi

# Mount the rootfs with options
mopts=""
[ -n "$rw" ]         && rootflags="${rootflags},rw"
[ -n "$ro" ]         && rootflags="${rootflags},ro"
[ -n "$rootflags" ]  && mopts="$mopts -o $rootflags"
[ -n "$rootfstype" ] && mopts="$mopts -t $rootfstype"
mount $mopts "`findblk "$root"`" /root || rescue "rootfs: mount failed with code $?"

# Update the fake root device node
printf "%s\n" "$root"|grep -q '/dev' && ln -sf "$root" /dev/root

# Mount the overlayfs
if [ -n "$overlay" ] || [ -n "$overlayfstype" ]; then
	# Move the existing root (new rom) away
	mkdir -p /rom /overlay
	mount --move /root /rom

	# Mount the upper (writable) source
	mopts=""
	[ -n "$overlayflags" ]  && mopts="$mopts -o $overlayflags"
	[ -n "$overlayfstype" ] && mopts="$mopts -t $overlayfstype"
	mount $mopts `findblk "$overlay"` /overlay || rescue "overlayfs: mount failed with code $?"

	# Data is for overwritten data, work is a tempdir for atomic renames by overlayfs
	mkdir -p /overlay/data /overlay/work

	# Mount the rom and the writable overlay together on /root
	mount -t overlay overlay -olowerdir=/rom,upperdir=/overlay/data,workdir=/overlay/work /root \
		|| rescue "overlaymount failed with code $?"
fi

# Check for some misc. conditions
[ -n "$rescue" ] && rescue "Rescue shell requested by kernel options"
[ -x "/root$init" ] || {
	echo "rootfs: $init not found... trying fallback /sbin/init..."
	#compatibility with systemd
	init=/sbin/init
}
[ -x "/root$init" ] || rescue "rootfs: $init not found"

# Inherit to rootfs
for dir in dev rom overlay boot; do [ -d /$dir ] && mkdir -p /root/$dir && mount --move /$dir /root/$dir; done

# Umount and forget
for dir in sys proc; do [ -d /$dir ] && umount /$dir; done

# Attempt final switch_root
exec switch_root /root "$init"
