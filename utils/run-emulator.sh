#!/bin/sh
# use: run-emulator.sh [no args, uses $H/config]
# runs the chroot under QEMU
 
export H="$PWD"
. ./config

console=
rw=rw
for i ; do
	[ "$i" = --console ] && console="console=ttyS0"
	[ "$i" = --ro ] && rw=ro
done
nographic=
[ -z "$console" ] || nographic="-nographic"
[ -z "$console" ] && console="vga=ask"
[ -z "$INIT" ] && INIT=/bin/init
[ -z "$KERNEL" ] && KERNEL=$R/boot/vmlinuz
[ -z "$ram" ] && ram=140

qemu-system-$A $nographic -m $ram -no-reboot -kernel $KERNEL -append \
  "root=root $rw rootflags=$rw,trans=virtio,version=9p2000.L rootfstype=9p init=$INIT panic=1 HOST=$A $console" \
  -fsdev local,id=root,path=$R,security_model=none -device virtio-9p-pci,fsdev=root,mount_tag=root
