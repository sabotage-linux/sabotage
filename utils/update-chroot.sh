#!/bin/sh
# use: update-chroot.sh [no args, uses $H/config]
# updates the chroot /src with the contents of the current sabotage checkout
 
MYDIR=$(dirname "$(readlink -f "$0")")
export H="$MYDIR/.."
. "$H"/config

if [ -z "$R" ] ; then
	echo "error sourcing config" >&2
	exit 1
fi

cp "$H"/COOKBOOK.md "$H"/LICENSE "$H"/README.md "$R"/src/
cp "$H"/build-stage0 "$H"/enter-chroot "$R"/src/
cp -r "$H"/KEEP "$H"/pkg "$H"/utils "$R"/src/
