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

cflags_base="-fno-unwind-tables -fno-asynchronous-unwind-tables -Wa,--noexecstack -fno-math-errno"
cflags_size="-Os -g0 -fdata-sections -ffunction-sections"
cflags_speed="-O3 -fstrength-reduce -fthread-jumps -fcse-follow-jumps -fcse-skip-blocks -frerun-cse-after-loop -fexpensive-optimizations -fforce-addr -fomit-frame-pointer"

ldflags_base="-Wl,-z,relro,-z,now -Wl,-z,text"
ldflags_size="-Wl,--gc-sections"

if [ "$OPT_KEEP_DEBUG" = 1 ] ; then
	cflags_base="$cflags_base -g"
else
	ldflags_base="$ldflags_base -s"
fi

optcflags="$cflags_size $cflags_base"
optldflags="$ldflags_size $ldflags_base"

[ "$isx86" = 1 ] || [ "$A" = x86_64 ] && [ "$isgcc3" = 0 ] && \
	optcflags="$optcflags -mtune=generic"

if [ "$OPT_SPEED" = 1 ] ; then
	optcflags="$cflags_base $cflags_speed -mtune=generic"

elif [ "$BRUTE" = 2 ] ; then
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

if [ "$STATICBUILD" = 1 ] ; then
	optldflags="$optldflags -static --static"
fi

if test "$1" = --dump ; then
	printf 'CFLAGS="%s"\n' "$optcflags"
	printf 'LDFLAGS="%s"\n' "$optldflags"
fi
