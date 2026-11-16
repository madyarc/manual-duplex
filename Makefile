PREFIX  ?= /usr
SYSCONFDIR ?= /etc
DESTDIR ?=

BINDIR  = $(PREFIX)/bin
UNITDIR = $(PREFIX)/lib/systemd/user
DOCDIR  = $(PREFIX)/share/doc/manual-duplex

.PHONY: all install uninstall check

all:

install:
	install -Dm755 bin/manual-duplex                $(DESTDIR)$(BINDIR)/manual-duplex
	install -Dm644 systemd/manual-duplex.path       $(DESTDIR)$(UNITDIR)/manual-duplex.path
	sed 's|/usr/bin/manual-duplex|$(BINDIR)/manual-duplex|' systemd/manual-duplex.service \
	  | install -Dm644 /dev/stdin                   $(DESTDIR)$(UNITDIR)/manual-duplex.service
	install -Dm644 cups/cups-pdf-Manual_Duplex.conf $(DESTDIR)$(SYSCONFDIR)/cups/cups-pdf-Manual_Duplex.conf
	install -Dm644 config.example                   $(DESTDIR)$(DOCDIR)/config.example
	install -Dm644 README.md                        $(DESTDIR)$(DOCDIR)/README.md
	install -Dm644 LICENSE                          $(DESTDIR)$(PREFIX)/share/licenses/manual-duplex/LICENSE

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/manual-duplex \
	      $(DESTDIR)$(UNITDIR)/manual-duplex.path \
	      $(DESTDIR)$(UNITDIR)/manual-duplex.service \
	      $(DESTDIR)$(SYSCONFDIR)/cups/cups-pdf-Manual_Duplex.conf
	rm -rf $(DESTDIR)$(DOCDIR) $(DESTDIR)$(PREFIX)/share/licenses/manual-duplex

check:
	bash -n bin/manual-duplex
	command -v shellcheck >/dev/null && shellcheck bin/manual-duplex || true
	systemd-analyze verify --user systemd/manual-duplex.path systemd/manual-duplex.service || true
