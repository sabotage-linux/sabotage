#!/bin/sh

# put your custom cflags and ldflags here...
# this file is sourced by the default butch build template

if [ "$DEBUGBUILD" = "1" ] ; then
	# use "DEBUGBUILD=1 butch install mypkg" to create debug version of mypkg
	optcflags="-O0 -g3"
	optldflags=
	return 0
elif [ "$TESTBUILD" = "1" ] ; then
	optcflags="-O0 -g0"
	optldflags=
	return 0
fi

is_gcc3() {
	local mycc="$CC"
	[ -z "$mycc" ] && mycc=gcc
	$mycc --version | grep "3.4.6" >/dev/null
}
isx86=0
case $A in i?86) isx86=1;; esac
isgcc3=0
[ "$STAGE" = 0 ] || is_gcc3 && isgcc3=1

optcflags="-fdata-sections -ffunction-sections -Os -g0 -fno-unwind-tables -fno-asynchronous-unwind-tables -Wa,--noexecstack"
optldflags="-s -Wl,--gc-sections -Wl,-z,relro,-z,now"
[ "$isx86" = 1 ] || [ "$A" = x86_64 ] && [ "$isgcc3" = 0 ] && \
	optcflags="$optcflags -mtune=generic"

if [ "$BRUTE" = 2 ] ; then
	optcflags="$optcflags -s -Os -flto -fwhole-program"
	optldflags="$optldflags -flto -fwhole-program"
elif [ "$BRUTE" = 1 ] ; then
        optcflags="$optcflags -s -Os -flto"
        optldflags="$optldflags -flto"
fi

if [ "$SECURE" = 1 ] ; then
	optcflags="$optcflags -fPIE -fstack-protector"
	optldflags="$optldflags -fpie"
fi
