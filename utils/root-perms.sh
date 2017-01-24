#!/bin/sh
# use: root-perms.sh <directory>
# set up default permissions on a directory intended to be used for a rootfs
 

if [ -z "$1" ] ; then
	echo "error: expecting directory name to apply root perms"
	exit 1
fi

if [ ! -e "$1"/bin ] ; then
	echo "error: $1 doesn't look like a sabotage rootfs"
	exit 1
fi
if [ ! -e "$1"/src/config ] ; then
echo "warning: /src/config missing. rootfs user may not be able to build things"
fi


for dir in / etc bin boot home include lib libexec mnt root sbin share src srv sys tmp usr var ; do
        chown -R root:root "$1"/$dir
done
chmod 0755 "$1"/var/empty
