#!/bin/sh
# no command line arguments - assume read from stdin
if [ -z "$1" ] || [ "$1" = - ] ; then
	curl -F 'sprunge=<-' http://sprunge.us
#file name argument: post to 0x0
elif [ -e "$1" ] ; then
	curl -F'file=@'"$1" https://0x0.st
else
cat << EOF
usage: head -n 20 foo.txt | $0
       $0 < foo.txt
text input from stdin will be pasted to http://sprunge.us
TODO: check if we want to use http://ix.io instead

usage: $0 filename
posts filename to https://0x0.st
this can be binary and up to 256MB.
EOF
fi
