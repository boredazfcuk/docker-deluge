#!/bin/ash
if [ "$(netstat -plnt | grep -c 58846)" -ne 1 ]; then
   echo "Deluge daemon not responding on port 58846"
   exit 1
fi
if [ "$(netstat -plnt | grep -c 8112)" -ne 1 ]; then
   echo "Deluge WebUI not responding on port 8112"
   exit 1
fi
echo "Deluge daemon and WebUI responding OK"
exit 0