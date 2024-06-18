#!/bin/sh
[ -z "$CONFIG" ] && CONFIG="$PWD/config"
[ ! -f "$CONFIG" ] && CONFIG=/src/config
if [ ! -f "$CONFIG" ] ; then
	echo "error: $CONFIG not found"
	exit 1
fi
export CONFIG
. "$CONFIG"

[ "$R" = "/" ] && R=
[ -z "$BUTCHDB" ] && BUTCHDB=$R/var/lib/butch.db

for pkg in gcc3 gcc424 stage0-gcc424 stage1-gcc424 stage0-gcc3 stage1-gcc3 stage0-musl bearssl; do
	"$K"/bin/butch-rm "$pkg" > /dev/null
done

for pkg in musl $("$K"/bin/butch-list | grep '^gcc[4-6][0-9][0-9]$' |tail -n1); do
	"$K"/bin/butch-relocate "$pkg" > /dev/null
done

echo "stage1-gcc3 1" >> "$BUTCHDB"
