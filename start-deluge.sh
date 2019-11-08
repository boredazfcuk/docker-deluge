#!/bin/ash

##### Functions #####
Initialise(){
   PAD="    "
   PID=$$
   PID="${PID:0:4}${PAD:0:$((4 - ${#PID}))}"
   LOGDIR="/tmp/deluge"
   LOG_DAEMON="deluge-daemon.log"
   LOG_WEB="deluge-web.log"
   DELUGEVERSION="$(usr/bin/deluge --version | grep deluge | awk '{print $2}')"
   PYTHONMAJOR="$(python3 --version | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}')"
   PACKAGES="/usr/lib/python${PYTHONMAJOR}/site-packages"
   LANIP="$(hostname -i)"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] ***** Starting Deluge v${DELUGEVERSION} *****"
   if [ ! -d "${LOGDIR}" ]; then mkdir -p "${LOGDIR}"; fi
   if [ ! -d "${PYTHON_EGG_CACHE}" ]; then mkdir "${PYTHON_EGG_CACHE}"; fi
   if [ ! -f "${LOGDIR}/${LOG_DAEMON}" ]; then touch "${LOGDIR}/${LOG_DAEMON}"; fi
   if [ ! -f "${LOGDIR}/${LOG_WEB}" ]; then touch "${LOGDIR}/${LOG_WEB}"; fi
   if [ -z "${USER}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] User name not set, defaulting to 'user'"; USER="user"; fi
   if [ -z "${UID}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] User ID not set, defaulting to '1000'"; UID="1000"; fi
   if [ -z "${GROUP}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Group name not set, defaulting to 'group'"; GROUP="group"; fi
   if [ -z "${GID}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Group ID not set, defaulting to '1000'"; GID="1000"; fi
   if [ ! -z  "$(ip a | grep tun. )" ]; then VPNIP="$(ip a | grep tun.$ | awk '{print $2}')"; echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] VPN tunnel adapter detected, binding daemon to ${VPNIP}"; fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Local user: ${USER}:${UID}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Local group: ${GROUP}:${GID}"

   if [ ! -f "${CONFIGDIR}/https" ]; then mkdir -p "${CONFIGDIR}/https"; fi
   if [ ! -f "${CONFIGDIR}/https/deluge.key" ]; then
      echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Generate private key for encrypting communications"
      openssl ecparam -genkey -name secp384r1 -out "${CONFIGDIR}/https/deluge.key"
   fi
   if [ ! -f "${CONFIGDIR}/https/deluge.csr" ]; then
      echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Create certificate request"
      openssl req -new -subj "/C=NA/ST=Global/L=Global/O=Deluge/OU=Deluge/CN=Deluge/" -key "${CONFIGDIR}/https/deluge.key" -out "${CONFIGDIR}/https/deluge.csr"
   fi
   if [ ! -f "${CONFIGDIR}/https/deluge.crt" ]; then
      echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Generate self-signed certificate request"
      openssl x509 -req -sha256 -days 3650 -in "${CONFIGDIR}/https/deluge.csr" -signkey "${CONFIGDIR}/https/deluge.key" -out "${CONFIGDIR}/https/deluge.crt"
   fi

   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure Deluge to use ${CONFIGDIR}/https/deluge.key key file"
   sed -i "s%\"pkey\": \".*%\"pkey\": \"${CONFIGDIR}\/https\/deluge.key\",%" "${CONFIGDIR}/web.conf"
   
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure Deluge to use ${CONFIGDIR}/https/deluge.crt certificate file"
   sed -i "s%\"cert\": \".*%\"cert\": \"${CONFIGDIR}\/https\/deluge.crt\",%" "${CONFIGDIR}/web.conf"

   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure Deluge to use HTTPS"
   sed -i "s%\"pkey\": \".*%\"pkey\": \"${CONFIGDIR}\/https\/deluge.key\",%" "${CONFIGDIR}/web.conf"

   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure Deluge web interface to listen on ${LANIP}"
   sed -i "s%\"interface\": \".*%\"interface\": \"${LANIP}\",%" "${CONFIGDIR}/web.conf"

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
      adduser -s /bin/ash -D -G "${GROUP}" -u "${UID}" "${USER}"
   elif [ ! "$(getent passwd "${USER}" | cut -d: -f3)" = "${UID}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] User ID already in use - exiting"
      exit 1
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Correct owner and group of application files, if required"
   find "${N2MBASE}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${N2MBASE}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${PYTHON_EGG_CACHE}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${PYTHON_EGG_CACHE}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${CONFIGDIR}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${CONFIGDIR}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${LOGDIR}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${LOGDIR}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${PACKAGES}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${PACKAGES}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
}

InstallnzbToMedia(){
   if [ ! -d "${N2MBASE}/.git" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] ${N2MREPO} not detected, installing..."
      chown "${USER}":"${GROUP}" "${N2MBASE}"
      cd "${N2MBASE}"
      su "${USER}" -c "git clone -b master https://github.com/${N2MREPO}.git ${N2MBASE}"
      if [ -f "/shared/autoProcessMedia.cfg" ]; then
         ln -s "/shared/autoProcessMedia.cfg" "${N2MBASE}/autoProcessMedia.cfg"
      else
         cp "${N2MBASE}/autoProcessMedia.cfg.spec" "/shared/autoProcessMedia.cfg"
         ln -s "/shared/autoProcessMedia.cfg" "${N2MBASE}/autoProcessMedia.cfg"
      fi
   fi
}

BindIP(){
   if [ ! -z "${VPNIP}" ]; then
      VPNADAPTER="$(ip a | grep tun.$ | awk '{print $7}')"
      sed -i "s/\"listen_interface\": .*,/\"listen_interface\": \"${VPNIP}\",/" "${CONFIGDIR}/core.conf"
      sed -i "s/\"outgoing_interface\": .*,/\"outgoing_interface\": \"${VPNADAPTER}\",/" "${CONFIGDIR}/core.conf"
   else
      echo "$(date '+%H:%M:%S') [ERROR   ][deluge.launcher.docker        :${PID}] No VPN adapters present. Private connection not available. Exiting"
      exit 1
   fi
}

LaunchDeluge(){
   tail -Fn0 "${LOGDIR}/${LOG_DAEMON}" &
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Starting Deluge daemon as ${USER}"
   su -m "${USER}" -c '/usr/bin/deluged -c '"${CONFIGDIR}"' -L warning -l '"${LOGDIR}/${LOG_DAEMON}"''
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Start Deluge webui as ${USER}"
   su -m "${USER}" -c '/usr/bin/deluge-web -c '"${CONFIGDIR}"' --base /deluge/ -L warning -l '"${LOGDIR}/${LOG_WEB}"''
   tail -Fn0 "${LOGDIR}/${LOG_WEB}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] ***** Stopping Deluge *****"
}

##### Script #####
Initialise
CreateGroup
CreateUser
SetOwnerAndGroup
InstallnzbToMedia
BindIP
LaunchDeluge