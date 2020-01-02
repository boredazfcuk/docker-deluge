#!/bin/ash
EXIT_CODE=0
EXIT_CODE="$(/usr/bin/deluge-console "connect localhost localclient $(grep ^localclient ${CONFIGDIR}/auth | cut -d: -f2)" >/dev/null 2>&1 | wc -c | grep -wq 0 | echo ${?})"
if [ "${EXIT_CODE}" != 0 ]; then
   echo "Console not responding: Error ${EXIT_CODE}"
   exit 1
fi
EXIT_CODE="$(wget --quiet --tries=1 --no-check-certificate --spider "https://${HOSTNAME}:8112/" && echo $?)"
if [ "${EXIT_CODE}" != 0 ]; then
   echo "WebUI not responding: Error ${EXIT_CODE}"
   exit 1
fi
echo "Console and WebUI available"
exit 0