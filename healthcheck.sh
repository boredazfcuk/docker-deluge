#!/bin/ash

DELUGECREDENTIALS="$(grep ^${USER} /config/auth | cut -d: -f1-2 | tr : ' ')"
/usr/bin/deluge-console "connect localhost ${DELUGECREDENTIALS}" 2>&1 | wc -c | grep -qw 0 || echo "Deluge Daemon not reachable on port 8112"; exit 1

wget -qSO /dev/null "http://${HOSTNAME}:8112/" || echo "Deluge Web not reachable on port 8112"; exit 1

exit 0