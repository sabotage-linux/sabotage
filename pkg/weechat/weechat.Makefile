prefix = /usr/local
bindir = $(prefix)/bin

PROG = weechat
SRCS =  \
../gui/curses/gui-curses-key.c \
../gui/gui-bar-item.c \
./wee-proxy.c \
../gui/gui-input.c \
../gui/gui-history.c \
./wee-hook.c \
./wee-hashtable.c \
../gui/curses/gui-curses-main.c \
../gui/curses/gui-curses-window.c \
../plugins/plugin-config.c \
../gui/gui-buffer.c \
weechat.c \
../gui/gui-focus.c \
./wee-config.c \
../gui/gui-cursor.c \
../gui/gui-filter.c \
./wee-upgrade.c \
../gui/gui-bar.c \
../gui/curses/gui-curses-term.c \
./wee-command.c \
../gui/curses/gui-curses-chat.c \
../gui/gui-chat.c \
./wee-version.c \
./wee-input.c \
./wee-backtrace.c \
../gui/gui-nicklist.c \
../gui/gui-hotlist.c \
../gui/gui-key.c \
./wee-eval.c \
./wee-infolist.c \
../plugins/plugin.c \
../gui/curses/gui-curses-mouse.c \
../gui/gui-bar-window.c \
./wee-hdata.c \
./wee-util.c \
../plugins/plugin-api.c \
./wee-debug.c \
../gui/curses/gui-curses-color.c \
../gui/curses/gui-curses-bar-window.c \
../gui/gui-completion.c \
./wee-completion.c \
../gui/gui-layout.c \
../gui/gui-line.c \
../gui/gui-mouse.c \
./wee-utf8.c \
./wee-list.c \
./wee-string.c \
./wee-config-file.c \
../gui/gui-color.c \
./wee-upgrade-file.c \
../gui/gui-window.c \
./wee-network.c \
./wee-url.c \
./wee-log.c
LIBS = 
OBJS = $(SRCS:.c=.o)

CFLAGS += -Wall -D_GNU_SOURCE -DHAVE_CONFIG_H

-include config.mak

all: $(PROG)

install: $(PROG)
	install -d $(DESTDIR)/$(bindir)
	install -D -m 755 $(PROG) $(DESTDIR)/$(bindir)/

clean:
	rm -f $(PROG)
	rm -f $(OBJS)

%.o: %.c
	$(CC) $(CFLAGS) $(INC) $(PIC) -c -o $@ $<

$(PROG): $(OBJS)
	 $(CC) $(LDFLAGS) $(OBJS) $(LIBS) -o $@

.PHONY: all clean install

