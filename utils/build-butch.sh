#!/bin/sh
filesize='55660'
sha512='c0565c79d937e5e971fbb78b8b68b80f2583949bd6d3256e2a7c538707d772cd4801b431903539d9b8c1ce57fc7cc0c63d633e9a931915e3821a799ee12e9805'
version=0.5.0

filename="$C"/butch-$version.tar.bz2

download() {
local try=0
	local limit=3
	local timeout=1
	while [ $try -ne $limit ]; do
		try=$((try+1))
		if ! wget -q -O "$filename" "$1" 2>/dev/null ; then
			printf -- "trouble downloading %s. fix your connection.\n" "$1"
			printf -- "%d tries remaining. waiting %d seconds\n" "$((limit-try))" "$timeout"
			sleep "$timeout"
		else
			# check if archive was completety downloaded
			# busybox' wget seem to be rather buggy
			if ! tar tjf "$2" >/dev/null ; then
				echo "partial download detected, retrying..."
			else
				break
			fi
		fi
	done
}

# use as: tarxf http://server/path/to/ file-1 .tar.gz [dirname]
tarxf() {
	cd "$C"
	[ -f "$2$3" ] || download "$1$2$3" "$2$3"
	mkdir -p "$S/build/$2"
	cd "$S/build/$2"
	rm -rf "${4:-$2}"
	tar xjf "$C/$2$3"
	cd "${4:-$2}"
}

getfilesize() {
	wc -c "$1" | cut -d " " -f 1
}

if [ -z "$BUTCH_BIN" ] ; then
	tarxf http://ftp.barfooze.de/pub/butch/ butch-$version .tar.bz2 ||
	tarxf http://foss.aueb.gr/mirrors/linux/butch/ butch-$version .tar.bz2

	sz=$(getfilesize "$filename")

	if [ "$sz" != "$filesize" ]; then
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

	if [ "$sha" != "$sha512" ]; then
			printf -- "error: build-butch: hash doesn't match.\n"
			exit 1
	fi

	# if on arm or mips, we only use one build thread to not exhaust memory
	[ "$A" = "arm" ] || [ "$A" = "mips" ] && sed -i \
	  's@#define NUM_BUILD_THREADS 2@#define NUM_BUILD_THREADS 1@' butch/butch.c

	MAKEFLAGS=-j$MAKE_THREADS ./build.sh 1>/dev/null 2>/dev/null
	BUTCH_BIN="$S/build/butch-$version/butch-$version/butch/butch"
fi
