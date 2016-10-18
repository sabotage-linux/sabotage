#!/bin/sh
BINDIR=$(dirname "$(readlink -f "$0")")
exec "$BINDIR"/../KEEP/bin/butch dlinfo $@

