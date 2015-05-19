#!/bin/sh
# use: hunt-library-tree.sh <search term> <elf file>
# searches "elf file" and its shared libraries for instances of "search term"
 
if [ -z "$1" -o -z "$2" ] ; then
        echo "Usage: hunt-library-tree <search term> <elf file>"
fi
if [ ! -z "$LD_LIBRARY_PATH" ] ; then
        libpath="$LD_LIBRARY_PATH":/lib
else
        libpath=/lib
fi

for i in $(readelf -a "$2" |grep NEEDED |sed -e 's/.*\[//g' |sed -e 's/\]//g') ; do
        for p in $(echo "$libpath" |sed s/:/\\n/g) ; do
		[ -f "$p"/"$i" ] && readelf -a "$p"/"$i" |grep "$1" |sed -e "s@^@$p/$i: @"
        done
done

readelf -a "$2" |grep "$1" |sed -e "s@^@$2: @"
readelf -a "$2" |grep NEEDED |sed -e 's@.*\[@@g' |sed -e 's@\]@@g'

exit 0
