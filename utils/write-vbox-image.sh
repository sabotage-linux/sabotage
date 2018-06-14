#!/bin/sh
# use: write-vbox-image.sh <name>
# creates a vmdk file in the current directory for use with VirtualBox

usage() {
	echo "use: $0 <name> <size> [options]"
	echo "options: --compress"
	echo
	echo "--compress will compress the new image with xz"
	echo
	echo "<size> will be passed directly to dd, so you can use whatever value dd supports, i.e. 8G"
	exit 1
}

if [ "$(id -u)" != "0" ]; then
    echo "error: need to be root"
    exit 1
fi

[ -z "$CONFIG" ] && CONFIG="$PWD/config"
[ ! -f "$CONFIG" ] && CONFIG=/src/config
if [ ! -f "$CONFIG" ] ; then
	echo "error: $CONFIG not found"
	exit 1
fi
export CONFIG
. "$CONFIG"

for i in qemu-img extlinux losetup ; do
	if ! type "$i" >/dev/null 2>&1 ; then
		echo "error: prerequisite $i not found in PATH" >&2
   		echo "try: butch install qemu util-linux extlinux" >&2
		exit 1
	fi
done

[ "$1" = "-h" ] && usage
[ "$1" = "--help" ] && usage

name="$1"
[ -z "$name" ] && echo "error: no name provided" && usage

size="$2"
[ -z "$size" ] && echo "error: must provide a size" && usage

cat <<'EOF' > "$SABOTAGE_BUILDDIR"/etc/motd

^[[1mwelcome to sabotage^[[0m

please review /src/README.md and /src/COOKBOOK.md for more information

a look at /etc/rc.local may also be of use

you may see the list of packages available with:

	$ ls /src/pkg

and install some with:

	$ butch install pkg1 <pkg2 pkg3 ...>
	$ butch install core       # basic utilities
	$ butch install core xorg  # utilties + basic desktop
	$ butch install world      # full desktop environment

^[[1mhave fun!^[[0m

EOF

sed -i -e's@do_dhcp=false@do_dhcp=true@g' "$SABOTAGE_BUILDDIR"/etc/rc.local

echo "creating image..."
"$S"/utils/write-hd-image.sh "$name".img "$SABOTAGE_BUILDDIR" "$size" --no-fstab >/dev/null 2>&1

echo "creating converting to vmdk..."
qemu-img convert -O vmdk "$name".img "$name".vmdk
rm "$name".img

if [ "$3" = "--compress" ] ; then
	echo "compressing image..."
	xz "$name".vmdk
fi

rm "$SABOTAGE_BUILDDIR"/etc/motd
touch "$SABOTAGE_BUILDDIR"/etc/motd

sed -i -e's@do_dhcp=false@do_dhcp=false@g' "$SABOTAGE_BUILDDIR"/etc/rc.local
