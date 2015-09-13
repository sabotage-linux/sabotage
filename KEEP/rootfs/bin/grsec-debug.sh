#!/bin/sh
# this script modifies grsecurity permissions on an executable
# so that it can be debugged with gdb.
if [ -z "$1" ] ; then
	echo "need to pass filename of binary to make debuggable"
	exit 1
fi

paxctl -c "$1" && paxctl -pemrxs "$1"

