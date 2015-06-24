#!/bin/sh

# put your custom cflags and ldflags here...
# this file is sourced by the default butch build template

isgcc3() {
	local mycc="$CC"
	[ -z "$mycc" ] && mycc=gcc
	$mycc --version | grep "3.4.6" >/dev/null
}

optcflags="-fdata-sections -ffunction-sections -Os -g0 -fno-unwind-tables -fno-asynchronous-unwind-tables -Wa,--noexecstack -pipe"
optldflags="-s -Wl,--gc-sections -Wl,-z,relro,-z,now"

if ! isgcc3; then
	if [ "$HARDENED" = "1" ]; then
		optcflags="$optcflags -fPIC -fstack-protector-all -D_FORTIFY_SOURCE=2 --param ssp-buffer-size=4"
		case "$A" in
			i?86) optldflags="-lssp_nonshared $optldflags";;
		esac
	elif [ "$HARDENED" = 2 ] ; then #incompatible with static builds
		optcflags="$optcflags -fPIC -fstack-protector-all -D_FORTIFY_SOURCE=2 --param ssp-buffer-size=4 -pie -fPIE"
		optldflags="$optldflags -pie"
		case "$A" in
			i?86) optldflags="-lssp_nonshared $optldflags";;
		esac
	fi

	if [ "$BRUTE" = 2 ] ; then #more agressive optimizations
		optcflags="$optcflags -O3 -flto=jobserver"
		optldflags="$optldflags -flto=jobserver"
	elif [ "$BRUTE" = 1 ] ; then #if you get "recompile with -fPIC" errors it's probably due to this
		optcflags="$optcflags -Os -flto=jobserver"
		optldflags="$optldflags -flto=jobserver"
	fi
fi

if [ "$DEBUGBUILD" = "1" ] ; then
	# use "DEBUGBUILD=1 butch install mypkg" to create debug version of mypkg
	optcflags="-O0 -g3"
	optldflags=
elif [ "$TESTBUILD" = "1" ] ; then
	optcflags="-O0 -g0"
	optldflags=
else
	[ "$STAGE" = "0" ] || isgcc3 || optcflags="$optcflags -ftree-dce"
fi
