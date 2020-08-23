#!/bin/ash

if [ "$(netstat -plnt | grep -c 58846)" -ne 1 ]; then
   echo "Deluge daemon not responding on port 58846"
   exit 1
fi

if [ "$(netstat -plnt | grep -c 8112)" -ne 1 ]; then
   echo "Deluge WebUI not responding on port 8112"
   exit 1
fi

if [ "$(hostname -i 2>/dev/null | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | wc -l)" -eq 0 ]; then
   echo "NIC missing"
   exit 1
fi

echo "Deluge daemon and WebUI responding OK"
exit 0