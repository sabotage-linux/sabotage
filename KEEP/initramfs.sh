#!/bin/busybox sh

rescue() {
	# Silence the kernel
	echo 0 > /proc/sys/kernel/printk
	echo "$@"
	PS1="(initramfs) \w\$ " exec /bin/sh
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
eval `cat /proc/cmdline|tr ' ' '\n'|grep '='`
eval `cat /proc/cmdline|tr ' ' '\n'|grep -v '='|sed 's/.$/&=1/'`

# Mount boot partition (required for CD boot)
if [ -n "${boot}" ]; then
	mkdir /boot
	mount "${boot}" /boot
fi

# Try to mount the cryptdevice
if [ -n "${crypt}" ]; then
	# Silence the kernel
	echo 0 > /proc/sys/kernel/printk
	cryptdev=$(printf "%s\n" "$crypt" | cut -d: -f1)
	mapper=$(printf "%s\n" "$crypt" | cut -d: -f2)
	cryptsetup luksOpen "`findfs $cryptdev`" "$mapper" \
		|| rescue "cryptsetup failed with code $?"
fi

# Scan around for lvm devices, see if you can find any
if [ -n "${lvm}" ]; then
	lvm vgscan
	lvm vgchange -a y
fi

# Mount the rootfs with options
mopts=""
[ -n "${rw}" ]         && rootflags="${rootflags},rw"
[ -n "${ro}" ]         && rootflags="${rootflags},ro"
[ -n "${rootflags}" ]  && mountopts="${mopts} -o ${rootflags}"
[ -n "${rootfstype}" ] && mountopts="${mopts} -t ${rootfstype}"
dev=$(findfs "${root}")
mount $mopts "${dev}" /root || rescue "rootfs: mount failed with code $?"

# Check for some misc. conditions
[ -x "/root${init}" ] || rescue "${init} not found"
[ -n "${rescue}" ] && rescue "Rescue shell requested by kernel options"

# Attempt final switch_root
umount /sys /proc
[ -d /boot ] && umount /boot
mount --move /dev /root/dev
exec switch_root /root "${init}"
rescue "switch_root failed with $?"
