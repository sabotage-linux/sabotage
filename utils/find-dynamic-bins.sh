#!/bin/sh
is_dynamic_bin() {
        readelf -l $1 2>/dev/null | grep -q 'INTERP'
}

for i in $(find /bin -type f -or -type l) ; do
	is_dynamic_bin "$i" && printf "%s\n" "$i"
done

