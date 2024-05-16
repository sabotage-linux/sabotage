#!/bin/sh

set -e

# Directory containing the new rootfs
Q="$1"

[ -z "$Q" ] && echo "Usage: $0 <rootfs>" && exit 1

cd /
rm -rf root include lib local tmp usr
rm $(find /bin -type f -not -name sh)

[ -e /etc/hostname ] && mv $Q/etc/hostname /etc/hostname.bak
[ -e /etc/hosts ] && mv $Q/etc/hosts /etc/hosts.bak
[ -e /etc/resolv.conf ] && mv $Q/etc/resolv.conf /etc/resolv.conf.bak

mv $Q/bin/* /bin
mv $Q/etc/* /etc

rm $Q/src
rmdir $Q/bin $Q/etc $Q/dev $Q/proc $Q/sys

mv -f $Q/* /
rmdir $Q
