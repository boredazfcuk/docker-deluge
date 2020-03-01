#!/bin/ash
if [ "$(nc -z localhost 58846; echo $?)" -ne 0 ]; then
   echo "Deluge daemon not responding on port 58846"
   exit 1
fi
if [ "$(nc -z "$(hostname -i)" 8112; echo $?)" -ne 0 ]; then
   echo "Deluge WebUI not responding on port 8112"
   exit 1
fi
echo "Deluge daemon and WebUI responding OK"
exit 0