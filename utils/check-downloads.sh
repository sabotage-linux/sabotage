#!/bin/sh
# use: cat pkg/* | utils/extract-links.sh | utils/check-downloads.sh
# check-downloads.sh will echo links wget reports broken

if (wget --help 2>&1 |grep -q BusyBox) ; then
        CMD='wget -s -T 60 -q'
else
        CMD='wget --spider --timeout 60 -q'
fi

while read p ; do
        $CMD "$p" 2>/dev/null || echo "$p"
done
