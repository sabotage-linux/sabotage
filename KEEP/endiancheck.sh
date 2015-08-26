#!/bin/sh
[ -z "$CC" ] && { echo "need CC var set">&2 ; exit 1 ; }
[ -z "$A" ] && { echo "need A (arch) var set">&2 ; exit 1 ; }
[ "$A" = i386 ] && { echo little ; exit 0 ; }
[ "$A" = i486 ] && { echo little ; exit 0 ; }
[ "$A" = i586 ] && { echo little ; exit 0 ; }
[ "$A" = i686 ] && { echo little ; exit 0 ; }
[ "$A" = x86_64 ] && { echo little ; exit 0 ; }
[ "$A" = x32 ] && { echo little ; exit 0 ; }
[ "$A" = powerpc ] && { echo big ; exit 0 ; }
tmpfile=/tmp/endiancheck.$$
$CC -dM -E - </dev/null > "$tmpfile"
endian=
[ "$A" = arm ] && {
	endian=little
	cat "$tmpfile" | grep __ARMEB__ >/dev/null && endian=big
	cat "$tmpfile" | grep __AARCH64EB__ >/dev/null && endian=big
}
[ "$A" = arm64 ] && {
	endian=little
	cat "$tmpfile" | grep __AARCH64EB__ >/dev/null && endian=big
}
[ "$A" = aarch64 ] && {
	endian=little
	cat "$tmpfile" | grep __AARCH64EB__ >/dev/null && endian=big
}
[ "$A" = mips ] && {
	endian=big
	cat "$tmpfile" | grep MIPSEL >/dev/null && endian=little
}
[ "$A" = microblaze ] && {
	cat "$tmpfile" | grep __MICROBLAZEEL__ >/dev/null && endian=little
}
[ "$A" = sh4 ] && {
	cat "$tmpfile" | grep __BIG_ENDIAN__ >/dev/null && endian=big
}
cat "$tmpfile" | grep __BIG_ENDIAN__ >/dev/null && endian=big
cat "$tmpfile" | grep __LITTLE_ENDIAN__ >/dev/null && endian=little
[ -z "$endian" ] && {
	$CC -include endian.h -dM -E - </dev/null > "$tmpfile"
	cat "$tmpfile" | grep "__BYTE_ORDER__ __ORDER_BIG_ENDIAN__" >/dev/null && endian=big
	cat "$tmpfile" | grep "__BYTE_ORDER__ __ORDER_LITTLE_ENDIAN__" >/dev/null && endian=little
}
rm "$tmpfile"
[ -z "$endian" ] && {
	echo "error: could not detect endianess" >&2
	exit 1
}
echo "$endian"
