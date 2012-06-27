# dwm version
VERSION = 6.0

# Customize below to fit your system

# paths
PREFIX = /
MANPREFIX = ${PREFIX}/share/man

X11INC = /opt/libx11/include
X11LIB = /opt/libx11/lib

# Xinerama
#XINERAMALIBS = -L${X11LIB} -lXinerama
#XINERAMAFLAGS = -DXINERAMA

# includes and libs
INCS = -I. -I/include -I${X11INC}
LIBS = -L/lib -lc -lXau -lXdmcp -lxcb -L${X11LIB} -lX11 -lX11-xcb ${XINERAMALIBS}

# flags
CPPFLAGS = -DVERSION=\"${VERSION}\" ${XINERAMAFLAGS}
#CFLAGS = -g -std=c99 -pedantic -Wall -O0 ${INCS} ${CPPFLAGS}
CFLAGS = -std=c99 -pedantic -Wall -Os ${INCS} ${CPPFLAGS}
#LDFLAGS = -g ${LIBS}
LDFLAGS = -s ${LIBS}

# Solaris
#CFLAGS = -fast ${INCS} -DVERSION=\"${VERSION}\"
#LDFLAGS = ${LIBS}

# compiler and linker
CC = musl-gcc
