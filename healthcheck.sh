#!/bin/ash
exit_code=0
exit_code="$(/usr/bin/deluge-console "connect localhost localclient $(grep ^localclient ${config_dir}/auth | cut -d: -f2)" >/dev/null 2>&1 | wc -c | grep -wq 0 | echo ${?})"
if [ "${exit_code}" != 0 ]; then
   echo "Console not responding: Error ${exit_code}"
   exit 1
fi
exit_code="$(wget --quiet --tries=1 --no-check-certificate --spider "https://${HOSTNAME}:8112/" && echo $?)"
if [ "${exit_code}" != 0 ]; then
   echo "WebUI not responding: Error ${exit_code}"
   exit 1
fi
echo "Console and WebUI available"
exit 0