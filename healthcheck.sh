#!/bin/ash
DELUGECREDENTIALS="$(grep ^${USER} /config/auth | cut -d: -f1-2 | tr : ' ')"
/usr/bin/deluge-console "connect localhost ${DELUGECREDENTIALS}" >/dev/null 2>&1 | wc -c | grep -wq 0 || exit 1
wget -q --spider "http://${HOSTNAME}:8112/" || exit 1
exit 0