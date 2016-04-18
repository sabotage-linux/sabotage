# sselp version
VERSION = 0.2

# Customize below to fit your system

# paths
PREFIX = 
MANPREFIX = ${PREFIX}/share/man

X11INC = /usr/X11R6/include
X11LIB = /usr/X11R6/lib

# includes and libs
INCS = -I. -I/usr/include -I${X11INC}
LIBS = -L/usr/lib -lc -L${X11LIB} -lX11

# flags
CPPFLAGS = -DVERSION=\"${VERSION}\"
CFLAGS = -std=c99 -pedantic -Wall -Os ${INCS} ${CPPFLAGS}
LDFLAGS = -s ${LIBS}

# compiler and linker
CC = cc
