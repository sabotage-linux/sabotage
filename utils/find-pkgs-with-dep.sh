#!/bin/sh
[ -z "$S" ] && echo 'error: $S not set. be sure to source config: . ./config' && exit 1
[ -z "$1" ] && echo 'error: please provide a package to search for.' && exit 1

for i in "$S"/pkg/* ; do
	if grep -q "^$1$" "$i" ; then
		basename "$i"
	fi
done

exit 0
