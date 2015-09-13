#!/bin/sh
# we already have a libc, thanks...
# getopt1 is left out because musl's impl behaves different as gnu expects.
culprits=`cat << EOF
getcwd
strtoul
clock
strncasecmp
fnmatch
waitpid
basename
strchr
snprintf
rindex
index
memcpy
mempcpy
strcasecmp
strsignal
vsprintf
strndup
bcmp
tmpnam
bzero
stpncpy
memchr
insque
ffs
vfork
memmove
stpcpy
bsearch
copysign
strtod
vsnprintf
strncmp
strtol
bcopy
rename
strstr
strerror
putenv
strdup
memset
memcmp
vprintf
calloc
gettimeofday
atexit
getpagesize
strverscmp
random
setenv
strrchr
asprintf
msdos
vasprintf
vfprintf
EOF
`
empty_file() {
        rm -f "$1"
        touch "$1"
}

dir="$1"
for i in $culprits ; do empty_file "$dir"/$i.c ; done

