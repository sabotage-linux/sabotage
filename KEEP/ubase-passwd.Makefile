include config.mk

.SUFFIXES:
.SUFFIXES: .o .c

HDR = \
	arg.h        \
	config.h     \
	passwd.h     \
	proc.h       \
	queue.h      \
	reboot.h     \
	rtc.h        \
	text.h       \
	util.h

LIBUTIL = libutil.a
LIBUTILSRC = \
	libutil/agetcwd.c        \
	libutil/agetline.c       \
	libutil/apathmax.c       \
	libutil/concat.c         \
	libutil/ealloc.c         \
	libutil/eprintf.c        \
	libutil/estrtol.c        \
	libutil/estrtoul.c       \
	libutil/explicit_bzero.c \
	libutil/passwd.c         \
	libutil/proc.c           \
	libutil/putword.c        \
	libutil/recurse.c        \
	libutil/strlcat.c        \
	libutil/strlcpy.c        \
	libutil/strtonum.c       \
	libutil/tty.c

LIB = $(LIBUTIL)

BIN = passwd

MAN1 = passwd.1

LIBUTILOBJ = $(LIBUTILSRC:.c=.o)
OBJ = $(BIN:=.o) $(LIBUTILOBJ)
SRC = $(BIN:=.c)

all: $(BIN)

$(BIN): $(LIB)

$(OBJ): $(HDR) config.mk

config.h:
	cp config.def.h $@

.o:
	$(CC) $(LDFLAGS) -o $@ $< $(LIB) $(LDLIBS)

.c.o:
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ -c $<

$(LIBUTIL): $(LIBUTILOBJ)
	$(AR) rc $@ $?
	$(RANLIB) $@

install: all
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f $(BIN) $(DESTDIR)$(PREFIX)/bin
	cd $(DESTDIR)$(PREFIX)/bin && chmod 755 $(BIN)
	mkdir -p $(DESTDIR)$(MANPREFIX)/man1
	for m in $(MAN1); do sed "s/^\.Os ubase/.Os ubase $(VERSION)/g" < "$$m" > $(DESTDIR)$(MANPREFIX)/man1/"$$m"; done
	cd $(DESTDIR)$(MANPREFIX)/man1 && chmod 644 $(MAN1)

uninstall:
	cd $(DESTDIR)$(PREFIX)/bin && rm -f $(BIN)
	cd $(DESTDIR)$(MANPREFIX)/man1 && rm -f $(MAN1)

dist: clean
	mkdir -p ubase-$(VERSION)
	cp -r LICENSE Makefile README TODO config.mk $(SRC) $(MAN1) $(MAN8) libutil $(HDR) config.def.h ubase-$(VERSION)
	tar -cf ubase-$(VERSION).tar ubase-$(VERSION)
	gzip ubase-$(VERSION).tar
	rm -rf ubase-$(VERSION)

clean:
	rm -f $(BIN) $(OBJ) $(LIB) ubase-box ubase-$(VERSION).tar.gz

.PHONY:
	all install uninstall dist ubase-box ubase-box-install clean
