#!/bin/sh
filesize='55660'
sha512='c0565c79d937e5e971fbb78b8b68b80f2583949bd6d3256e2a7c538707d772cd4801b431903539d9b8c1ce57fc7cc0c63d633e9a931915e3821a799ee12e9805'
version=0.5.0

filename="$C/butch-$version.tar.bz2"

if [ ! -f "$filename" ] ; then
	try=0
	limit=3
	while [ "$try" -ne "$limit" ] ; do
		try=$((try+1))
			
		wget -q -O "$filename" http://ftp.barfooze.de/pub/butch/butch-$version.tar.bz2 2>/dev/null || \
		  wget -q -O "$filename" http://foss.aueb.gr/mirrors/linux/butch/butch-$version.tar.bz2 2>/dev/null || true

		if ! tar tjf "$filename" >/dev/null ; then
			echo "warning: partial download detected, retrying..."
		else
			break
		fi		
		printf -- "%d tries remaining. waiting a second\n" "$((limit - try))"
		sleep 1
	done
fi

sz=$(wc -c "$filename" | cut -d " " -f 1)

if [ "$sz" != "$filesize" ] ; then
	printf -- "error: build-butch: wrong filesize. got: %d expected: %d\n" "$sz" "$filesize"
	exit 1
fi

if ! which sha512sum > /dev/null ; then
	echo "warning: sha512sum utility not found, disabling hash check"
	sha="$sha512"
	sleep 2
else
	read sha _ <<-EOF
		$(sha512sum "$filename")
		EOF
fi
if [ "$sha" != "$sha512" ] ; then
	printf -- "error: build-butch: hash doesn't match\n"
	exit 1
fi

mkdir -p "$S/build/butch-$version" && cd "$S/build/butch-$version"
tar xjf "$C/butch-$version.tar.bz2" && cd "butch-$version"                                                                                                                        

# if on arm or mips, we only use one build thread to not exhaust memory
[ "$A" = "arm" ] || [ "$A" = "mips" ] && sed -i \
  's@#define NUM_BUILD_THREADS 2@#define NUM_BUILD_THREADS 1@' butch/butch.c

MAKEFLAGS=-j$MAKE_THREADS ./build.sh 1>/dev/null 2>/dev/null
BUTCH_BIN="$S/build/butch-$version/butch-$version/butch/butch"
