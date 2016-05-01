#!/bin/sh
export PATH=/bin

echo sabotage booting

mount -t proc proc /proc
mount -t sysfs sysfs /sys

if which udevd > /dev/null 2>&1 ; then
	# mount -t devtmpfs -o mode=0755,nosuid dev /dev
	mkdir -p /run
	mount -t tmpfs -o nosuid,nodev,mode=0755 run /run
	echo > /proc/sys/kernel/hotplug
	/bin/udevd --daemon
	/bin/udevadm trigger --action=add    --type=subsystems
	/bin/udevadm trigger --action=add    --type=devices
	/bin/udevadm trigger --action=change --type=devices
	/bin/udevadm settle

else
	echo /sbin/mdev > /proc/sys/kernel/hotplug
	mdev -s
fi

# only show warning or worse on console
grep -q " verbose" /proc/cmdline && dmesg -n 8 || dmesg -n 3

hwclock -u -s

hostname $(cat /etc/hostname)
ifconfig lo up

rw=true
rwtest=/tmp/rwtest.tmp
if touch "$rwtest" 2>/dev/null; then
	rm "$rwtest"
else
	rw=false
fi

cryptmount -M # make encrypted devices from /etc/crypttab available

$rw && mount -o remount,ro /
fsck -A -T -C -p
mkdir -p /dev/shm /dev/pts
$rw && mount -o remount,rw /

swapon -a

mount -a # mount stuff from /etc/fstab

if touch "$rwtest" 2>/dev/null; then
  rm "$rwtest"
  rw=true
else
  rw=false
fi

if ! $rw ; then
	echo "non-writable fs detected, mounting tmpfs to /var and /tmp"
	# tmpfs defaults to -o size=50%
	mount -t tmpfs -o mode=1777 tmpfs /tmp
	mount -t tmpfs -o size=1M,mode=751 tmpfs /var
	mkdir -p /var/spool/cron/crontabs /var/service /var/log /var/empty
	ln -sf /tmp /var/tmp
	( cd /etc/service
	for i in * ; do
		# we copy the services instead of symlinking, so subdirs can be created
		cp -rf /etc/service/$i /var/service/
		mkdir -p /var/log/$i
	done
	)
fi

[ -f /etc/random-seed ] && cat /etc/random-seed >/dev/urandom
dd if=/dev/urandom of=/etc/random-seed count=1 bs=512 2>/dev/null

dmesg >/var/log/dmesg.log

for i in /etc/rc.modules /etc/rc.local ; do
	[ -x "$i" ] && "$i"
done
