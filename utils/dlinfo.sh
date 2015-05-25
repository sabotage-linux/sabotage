#!/bin/sh
# use: utils/dlinfo.sh <url>
# download url, return butch recipe [main] and [mirror] values

set -e
 
url=$1
if [ -z "$url" ] ; then
	echo error, expecting an url as argument 1>&2
	exit 1
elif [ ! -d "tarballs" ] ; then
	echo error, tarballs dir does not exist 1>&2
	exit 1
fi

geturlfilename() {
	echo ${url##*/}
}

getfilesize() {
	wc -c "$1" | cut -d ' ' -f 1
}

gethash() {
	sha512sum "$1" | cut -d ' ' -f 1
}

fn=tarballs/`geturlfilename "$url"`
if [ "$USE_CURL" = 1 ] ; then
	curl -c /dev/null -C - -k -L "$url" -o "$fn"
else
	wget --no-check-certificate -O "$fn" "$url"
fi
echo [mirrors]
echo "$url"
echo
echo [main]
echo filesize=`getfilesize "$fn"`
echo sha512=`gethash "$fn"`

