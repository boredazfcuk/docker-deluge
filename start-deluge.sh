#!/bin/ash

##### Functions #####
Initialise(){
   PAD="    "
   PID=$$
   PID="${PID:0:4}${PAD:0:$((4 - ${#PID}))}"
   LOGDIR="/tmp" \
   LOG_DAEMON="deluge-daemon.log" \
   LOG_WEB="deluge-web.log"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] ***** Starting Deluge *****"
   if [ ! -d "${PYTHON_EGG_CACHE}" ]; then mkdir "${PYTHON_EGG_CACHE}"; fi
   if [ -f "${LOGDIR}/${LOG_DAEMON}" ]; then rm "${LOGDIR}/${LOG_DAEMON}"; ln -s /dev/stdout "${LOGDIR}/${LOG_DAEMON}"; fi
   if [ -f "${LOGDIR}/${LOG_WEB}" ]; then rm "${LOGDIR}/${LOG_WEB}"; ln -s /dev/stdout "${LOGDIR}/${LOG_WEB}"; fi
   if [ -z "${USER}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] User name not set, defaulting to 'user'"; USER="user"; fi
   if [ -z "${UID}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] User ID not set, defaulting to '1000'"; UID="1000"; fi
   if [ -z "${GROUP}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Group name not set, defaulting to 'group'"; GROUP="group"; fi
   if [ -z "${GID}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Group ID not set, defaulting to '1000'"; GID="1000"; fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Local user: ${USER}:${UID}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Local group: ${GROUP}:${GID}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Deluge application directory: ${APPBASE}"
}

CreateGroup(){
   if [ -z "$(getent group "${GROUP}" | cut -d: -f3)" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Group ID available, creating group"
      addgroup -g "${GID}" "${GROUP}"
   elif [ ! "$(getent group "${GROUP}" | cut -d: -f3)" = "${GID}" ]; then
      echo "$(date '+%H:%M:%S') [ERROR   ][deluge.launcher.docker        :${PID}] Group GID mismatch - exiting"
      exit 1
   fi
}

CreateUser(){
   if [ -z "$(getent passwd "${USER}" | cut -d: -f3)" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] User ID available, creating user"
      adduser -s /bin/ash -H -D -G "${GROUP}" -u "${UID}" "${USER}"
   elif [ ! "$(getent passwd "${USER}" | cut -d: -f3)" = "${UID}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] User ID already in use - exiting"
      exit 1
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Correct owner and group of application files, if required"
   find "${APPBASE}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${APPBASE}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${N2MBASE}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${N2MBASE}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${PYTHON_EGG_CACHE}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${PYTHON_EGG_CACHE}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${CONFIGDIR}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${CONFIGDIR}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${LOGDIR}" -name "${LOG_DAEMON}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${LOGDIR}" -name "${LOG_WEB}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
}

LaunchDeluge(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Starting Deluge as ${USER}"
   su -m "${USER}" -c '/usr/bin/deluged -c '"${CONFIGDIR}"' -L info -l '"${LOGDIR}/${LOG_DAEMON}"''
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Start Deluge webui"
   su -m "${USER}" -c '/usr/bin/deluge-web -c '"${CONFIGDIR}"' -L error -l '"${LOGDIR}/${LOG_WEB}"''
   sleep 999999h
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] ***** Stopping Deluge *****"
}

##### Script #####
Initialise
CreateGroup
CreateUser
SetOwnerAndGroup
LaunchDeluge