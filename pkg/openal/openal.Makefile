prefix=/
bindir=$(prefix)/bin
includedir=$(prefix)/include
libdir=$(prefix)/lib
sysconfdir=$(prefix)/etc

AL32SRC = $(sort $(wildcard OpenAL32/*.c))
ALCSRC = $(sort $(wildcard Alc/*.c))
BACKENDS = Alc/backends/null.c Alc/backends/loopback.c Alc/backends/alsa.c 


SRCS = $(AL32SRC) $(ALCSRC) $(BACKENDS)
OBJS = $(SRCS:.c=.o)

ALHEADERS = $(sort $(wildcard include/AL/*.h))
ALL_INCLUDES = $(ALHEADERS)

ALL_LIBS=lib/libopenal.so

CFLAGS=-include config.h -Iinclude/ -I OpenAL32/Include -fPIC -O0 -g -std=gnu99 -D_GNU_SOURCE

-include config.mak

BUILDCFLAGS=$(CFLAGS)

all: $(ALL_LIBS)

install: $(ALL_LIBS:lib/%=$(DESTDIR)$(libdir)/%) $(ALL_INCLUDES:include/%=$(DESTDIR)$(includedir)/%) $(DESTDIR)$(sysconfdir)/openal/alsoft.conf

clean:
	rm -f $(ALL_LIBS)
	rm -f $(OBJS)

%.o: %.c
	$(CC) $(BUILDCFLAGS) -c -o $@ $<

lib/libopenal.so: $(OBJS)
	$(CC) -shared $(LDFLAGS) -Wl,-soname=libopenal.so -o $@ $(OBJS) -lasound

$(DESTDIR)$(libdir)/%.so: lib/%.so
	install -D -m 755 $< $@

$(DESTDIR)$(includedir)/%: include/%
	install -D -m 644 $< $@

$(DESTDIR)$(sysconfdir)/openal/alsoft.conf: alsoftrc.sample
	install -D -m 644 $< $@

.PHONY: all clean install



