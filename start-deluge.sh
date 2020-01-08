#!/bin/ash

##### Functions #####
Initialise(){
   PAD="    "
   PID=$$
   PID="${PID:0:4}${PAD:0:$((4 - ${#PID}))}"
   LOG_DIR="/var/tmp/deluge"
   LOG_DAEMON="deluge-daemon.log"
   DELUGEVERSION="$(usr/bin/deluge --version | grep deluge | awk '{print $2}')"
   PYTHONMAJOR="$(python3 --version | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}')"
   PACKAGES="/usr/lib/python${PYTHONMAJOR}/site-packages"
   N2MREPO="clinton-hall/nzbToMedia"
   N2MBASE="/nzbToMedia"
   LANIP="$(hostname -i)"
   if [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** GeoIP Country database does not exist, waiting for it to be created ****"; while [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; do sleep 2; done; fi
   echo -e "\n"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] ***** Starting Deluge v${DELUGEVERSION} *****"
   if [ ! -d "${PYTHON_EGG_CACHE}" ]; then mkdir "${PYTHON_EGG_CACHE}"; fi
   if [ -z "${STACKUSER}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User name not set, defaulting to 'stackman'"; STACKUSER="stackman"; fi
   if [ -z "${STACKPASSWORD}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Password not set, defaulting to 'Skibidibbydibyodadubdub'"; STACKPASSWORD="Skibidibbydibyodadubdub"; fi   
   if [ -z "${UID}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] User ID not set, defaulting to '1000'"; UID="1000"; fi
   if [ -z "${GROUP}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Group name not set, defaulting to 'group'"; GROUP="group"; fi
   if [ -z "${GID}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Group ID not set, defaulting to '1000'"; GID="1000"; fi
   if [ -z "${MOVIECOMPLETEDIR}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Category complete path not set for movie, defaulting to /storage/downloads/complete/movie/"; MOVIECOMPLETEDIR="/storage/downloads/complete/movie/"; fi
   if [ -z "${MUSICCOMPLETEDIR}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Category complete path not set for music, defaulting to /storage/downloads/complete/music/"; MUSICCOMPLETEDIR="/storage/downloads/complete/music/"; fi
   if [ -z "${OTHERCOMPLETEDIR}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Category complete path not set for other, defaulting to /storage/downloads/complete/other/"; OTHERCOMPLETEDIR="/storage/downloads/complete/other/"; fi
   if [ -z "${TVCOMPLETEDIR}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Category complete path not set for tv, defaulting to /storage/downloads/complete/tv/"; TVCOMPLETEDIR="/storage/downloads/complete/tv/"; fi
   if [ -z "${DELUGEWATCHDIR}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Watch path not set, defaulting to /storage/downloads/watch/deluge/"; DELUGEWATCHDIR="/storage/downloads/watch/deluge/"; fi
   if [ -z "${DELUGEFILEBACKUPDIR}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Torrent backup path not set, defaulting to /storage/downloads/backup/deluge/"; DELUGEFILEBACKUPDIR="/storage/downloads/backup/deluge/"; fi
   if [ -z "${DELUGEINCOMINGDIR}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Download path not set, defaulting to /storage/downloads/incoming/deluge/"; DELUGEINCOMINGDIR="/storage/downloads/incoming/deluge/"; fi
   if [ -z "${DOWNLOADCOMPLETEDIR}" ]; then echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${PID}] Download complete path not set, defaulting to /storage/downloads/complete/"; DOWNLOADCOMPLETEDIR="/storage/downloads/complete/"; fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Local user: ${STACKUSER}:${UID}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Local group: ${GROUP}:${GID}"
   DELUGEABSPATHWATCHDIR="${DELUGEWATCHDIR%/}"
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
   if [ -z "$(getent passwd "${STACKUSER}" | cut -d: -f3)" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] User ID available, creating user"
      adduser -s /bin/ash -D -G "${GROUP}" -u "${UID}" "${STACKUSER}"
   elif [ ! "$(getent passwd "${STACKUSER}" | cut -d: -f3)" = "${UID}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] User ID already in use - exiting"
      exit 1
   fi
}

CreateLogFile(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Create log directory and daemon log file"
   mkdir -p "${LOG_DIR}"
   touch "${LOG_DIR}/${LOG_DAEMON}"
   chown -R "${STACKUSER}":"${GROUP}" "${LOG_DIR}"
}

FirstRun(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] ***** First run detected, creating configuration *****"
   find "${CONFIGDIR}" ! -user "${STACKUSER}" -exec chown "${STACKUSER}" {} \;
   find "${CONFIGDIR}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   if [ ! -f "${LOG_DIR}/${LOG_DAEMON}" ]; then CreateLogFile; fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Starting Deluge daemon as ${STACKUSER} to generate default configuration"
   su "${STACKUSER}" -c "/usr/bin/deluged --config ${CONFIGDIR} --logfile ${LOG_DIR}/${LOG_DAEMON} --loglevel none"
   sleep 5
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Enable AutoAdd, Blocklist, Execute, Label & Scheduler plugins"
   /usr/bin/deluge-console -U localclient -P "$(grep ^localclient ${CONFIGDIR}/auth | cut -d: -f2)" plugin --enable AutoAdd Blocklist Execute Label Scheduler
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Start Deluge webui as ${STACKUSER} to generate default configuration"
   su "${STACKUSER}" -c "/usr/bin/deluge-web --config ${CONFIGDIR} --loglevel none"
   sleep 10
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Stop Deluge daemon and webui to make configuration changes"
   pkill deluged
   pkill deluge-web
   sleep 5
   if [ -f "${CONFIGDIR}/session.state" ] && [ ! -f "${CONFIGDIR}/session.state.bak" ]; then
      cp -rp "${CONFIGDIR}/session.state" "${CONFIGDIR}/session.state.bak"
   fi
   DAEMONGUID="$(grep -A2 hosts "${CONFIGDIR}/hostlist.conf" | tail -n1 | tr "[:upper:]" "[:lower:]" | sed 's/[^0-9a-f]*//g')"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Set default language to English to suppress error"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Disable first login option"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Enable web autoconnect to daemon"
   sed -i \
      -e "s%\"language\": \".*%\"language\": \"en_GB\",%" \
      -e "s%\"first_login\": .*%\"first_login\": false,%" \
      -e "s%\"default_daemon\": \".*%\"default_daemon\": \"${DAEMONGUID}\",%" \
      "${CONFIGDIR}/web.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Set listening port to 57700"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Set outgoing port range to 58800-59900"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Set torrent backup location"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Ignore slow torrents"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Set download location"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Pre-allocate storage"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Prioritise first and last pieces"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Queue new to top"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Set completed download location"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Disable UPnP"
   sed -i \
      -e "/listen_ports/,/\s\],$/ s/^\(\s\+\)\([0-9]\+,$\)/\157700,/1" \
      -e "/listen_ports/,/\s\],$/ s/^\(\s\+\)\([0-9]\+$\)/\157700/1" \
      -e "/outgoing_ports/,/\s\],$/ s/^\(\s\+\)\([0-9]\+,$\)/\158800,/1" \
      -e "/outgoing_ports/,/\s\],$/ s/^\(\s\+\)\([0-9]\+$\)/\159900/1" \
      -e "s%\"random_outgoing_ports\": .*%\"random_outgoing_ports\": false,%" \
      -e "s%\"random_port\": .*%\"random_port\": false,%" \
      -e "s%\"copy_torrent_file\": .*%\"copy_torrent_file\": true,%" \
      -e "s%\"dont_count_slow_torrents\": .*%\"dont_count_slow_torrents\": true,%" \
      -e "s%\"move_completed\": .*%\"move_completed\": true,%" \
      -e "s%\"pre_allocate_storage\": .*%\"pre_allocate_storage\": true,%" \
      -e "s%\"prioritize_first_last_pieces\": .*%\"prioritize_first_last_pieces\": true,%" \
      -e "s%\"queue_new_to_top\": .*%\"queue_new_to_top\": false,%" \
      -e "s%\"upnp\": .*%\"upnp\": false,%" \
      "${CONFIGDIR}/core.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Enable plugins"
   sed -i \
      -e "/enabled_plugins/ s/^\(\s\+\)\(\"enabled_plugins\": \[\)\(\],\)/\1\2\n\1\3/" \
      "${CONFIGDIR}/web.conf"
   sed -i \
      -e "/enabled_plugins/a \"AutoAdd\"," \
      -e "/enabled_plugins/a \"Blocklist\"," \
      -e "/enabled_plugins/a \"Execute\"," \
      -e "/enabled_plugins/a \"Label\"," \
      -e "/enabled_plugins/a \"Scheduler\"" \
      "${CONFIGDIR}/web.conf"
   sed -i \
      -e "s/^\(\"AutoAdd\",\)/        \1/" \
      -e "s/^\(\"Blocklist\",\)/        \1/" \
      -e "s/^\(\"Execute\",\)/        \1/" \
      -e "s/^\(\"Label\",\)/        \1/" \
      -e "s/^\(\"Scheduler\"\)/        \1/" \
      "${CONFIGDIR}/web.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure Blocklist plugin"
   sed -i \
      -e "s%\"list_type\": .*%\"list_type\": \"SafePeer\",%" \
      -e "s%\"list_compression\": .*%\"list_compression\": \"GZip\",%" \
      -e "s%\"load_on_start\": .*%\"load_on_start\": true,%" \
      -e "s%\"url\": .*%\"url\": \"http://john.bitsurge.net/public/biglist.p2p.gz\",%" \
      "${CONFIGDIR}/blocklist.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure Execute plugin"
   sed -i \
      -e "s%\"\",%\"$(head /dev/urandom | tr -dc a-f0-9 | head -c40)\",%" \
      "${CONFIGDIR}/execute.conf"
   echo -e "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Set WebUI password to \x27${STACKPASSWORD}\x27"
   PASSHASH="$(echo -n "$(grep pwd_salt ${CONFIGDIR}/web.conf | awk '{print $2}' | sed 's/[^[:alnum:]]//g')${STACKPASSWORD}" | sha1sum | awk '{print $1}')"
   sed -i \
      -e "s%\"pwd_sha1\": \".*%\"pwd_sha1\": \"${PASSHASH}\",%" \
      "${CONFIGDIR}/web.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] ***** First run configuration complete *****"
}

EnableSSL(){
   if [ ! -d "${CONFIGDIR}/https" ]; then
      mkdir -p "${CONFIGDIR}/https"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure HTTPS"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Generate server key"
      openssl ecparam -genkey -name secp384r1 -out "${CONFIGDIR}/https/deluge.key"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Generate certificate request"
      openssl req -new -subj "/C=NA/ST=Global/L=Global/O=Deluge/OU=Deluge/CN=Deluge/" -key "${CONFIGDIR}/https/deluge.key" -out "${CONFIGDIR}/https/deluge.csr"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Generate certificate"
      openssl x509 -req -sha256 -days 3650 -in "${CONFIGDIR}/https/deluge.csr" -signkey "${CONFIGDIR}/https/deluge.key" -out "${CONFIGDIR}/https/deluge.crt" >/dev/null 2>&1
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Enable HTTPS"
      sed -i -e "s%\"pkey\": \".*%\"pkey\": \"${CONFIGDIR}\/https\/deluge.key\",%" \
         -e "s%\"cert\": \".*%\"cert\": \"${CONFIGDIR}\/https\/deluge.crt\",%" \
         -e "s%\"https\": .*%\"https\": true,%" "${CONFIGDIR}/web.conf"
   fi
}

Configure(){
   sleep 5
   if [ ! -f "${LOG_DIR}/${LOG_DAEMON}" ]; then CreateLogFile; fi
   if [ ! -z  "$(ip a | grep tun. )" ]; then
      VPNIP="$(ip a | grep tun.$ | awk '{print $2}')"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] VPN tunnel adapter detected, binding daemon to ${VPNIP}"
   fi
   if [ ! -z "${VPNIP}" ]; then
      VPNADAPTER="$(ip a | grep tun.$ | awk '{print $7}')"
      sed -i \
         -e "s/\"listen_interface\": .*,/\"listen_interface\": \"${VPNIP}\",/" \
         -e "s/\"outgoing_interface\": .*,/\"outgoing_interface\": \"${VPNADAPTER}\",/" \
         "${CONFIGDIR}/core.conf"
   else
      echo "$(date '+%H:%M:%S') [ERROR   ][deluge.launcher.docker        :${PID}] No VPN adapters present. Private connection not available. Exiting"
   fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Binding WebUI to ${LANIP}"
   sed -i \
      -e "s%\"interface\": \".*%\"interface\": \"${LANIP}\",%" \
      "${CONFIGDIR}/web.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure downloads path: ${DELUGEINCOMINGDIR}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure completed downloads path: ${DOWNLOADCOMPLETEDIR}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure torrent backup path: ${DELUGEFILEBACKUPDIR}"
   sed -i \
      -e "s%\"download_location\": .*%\"download_location\": \"${DELUGEINCOMINGDIR}\",%" \
      -e "s%\"move_completed_path\": .*%\"move_completed_path\": \"${DOWNLOADCOMPLETEDIR}\",%" \
      -e "s%\"torrentfiles_location\": .*%\"torrentfiles_location\": \"${DELUGEFILEBACKUPDIR}\",%" \
      "${CONFIGDIR}/core.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure Labels plugin paths: ${MOVIECOMPLETEDIR}, ${MUSICCOMPLETEDIR}, ${OTHERCOMPLETEDIR} & ${TVCOMPLETEDIR}"
   sed -i \
      -e "/\"movie\": {$/,/},/ s/\"move_completed\": .*/\"move_completed\": true,/" \
      -e "/\"movie\": {$/,/},/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${MOVIECOMPLETEDIR}\",%" \
      -e "/\"music\": {$/,/},/ s/\"move_completed\": .*/\"move_completed\": true,/" \
      -e "/\"music\": {$/,/},/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${MUSICCOMPLETEDIR}\",%" \
      -e "/\"other\": {$/,/},/ s/\"move_completed\": .*/\"move_completed\": true,/" \
      -e "/\"other\": {$/,/},/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${OTHERCOMPLETEDIR}\",%" \
      -e "/\"tv\": {$/,/},/ s/\"move_completed\": .*/\"move_completed\": true,/" \
      -e "/\"tv\": {$/,/},/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${TVCOMPLETEDIR}\",%" \
      "${CONFIGDIR}/label.conf"
   LABEL="movie"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure AutoAdd plugin for ${LABEL} downloads"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure AutoAdd plugin base watch dir location: ${DELUGEABSPATHWATCHDIR}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure AutoAdd plugin backup file location: ${DELUGEFILEBACKUPDIR}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure AutoAdd plugin download location: ${DELUGEINCOMINGDIR}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure AutoAdd plugin movie watch location: ${DELUGEWATCHDIR}${LABEL}/"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure AutoAdd plugin completed download location: ${DOWNLOADCOMPLETEDIR}"
   sed -i \
      -e "/\"1\": {$/,/}/ s%\"label\": .*%\"label\": \"${LABEL}\",%" \
      -e "/\"1\": {$/,/}/ s%\"path\": .*%\"path\": \"${DELUGEWATCHDIR}${LABEL}\/\",%" \
      -e "/\"1\": {$/,/}/ s%\"abspath\": .*%\"abspath\": \"${DELUGEABSPATHWATCHDIR}\",%" \
      -e "/\"1\": {$/,/}/ s%\"copy_torrent\": .*%\"copy_torrent\": \"${DELUGEFILEBACKUPDIR}\",%" \
      -e "/\"1\": {$/,/}/ s%\"download_location\": .*%\"download_location\": \"${DELUGEINCOMINGDIR}\",%" \
      -e "/\"1\": {$/,/}/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${DOWNLOADCOMPLETEDIR}\",%" \
      "${CONFIGDIR}/autoadd.conf"
}

InstallnzbToMedia(){
   if [ ! -d "${N2MBASE}" ]; then
      mkdir -p "${N2MBASE}"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] ${N2MREPO} not detected, installing..."
      chown "${STACKUSER}":"${GROUP}" "${N2MBASE}"
      cd "${N2MBASE}"
      su "${STACKUSER}" -c "git clone --quiet --branch master https://github.com/${N2MREPO}.git ${N2MBASE}"
      if [ ! -f "${N2MBASE}/autoProcessMedia.cfg" ]; then
         cp "${N2MBASE}/autoProcessMedia.cfg.spec" "${N2MBASE}/autoProcessMedia.cfg"
      fi
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Change nzbToMedia default configuration"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%auto_update =.*%auto_update = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%git_path =.*%git_path = /usr/bin/git%" \
         -e "/^\[General\]/,/^\[.*\]/ s%ffmpeg_path = *%ffmpeg_path = /usr/local/bin/ffmpeg%" \
         -e "/^\[General\]/,/^\[.*\]/ s%safe_mode =.*%safe_mode = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%no_extract_failed =.*%no_extract_failed = 1%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%clientAgent =.*%clientAgent = deluge%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%useLink =.*%useLink = move-sym%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%categories =.*%categories = tv, movie, music%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugeHost =.*%DelugeHost = 127.0.0.1%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugePort =.*%DelugePort = 58846%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugeUSR =.*%DelugeUSR = localclient%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugePWD =.*%DelugePWD = $(grep ^localclient ${CONFIGDIR}/auth | cut -d: -f2)%" \
         "${N2MBASE}/autoProcessMedia.cfg"
   fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure nzbToMedia download paths"
   sed -i \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%outputDirectory =.*%outputDirectory = ${OTHERCOMPLETEDIR}%" \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%default_downloadDirectory =.*%default_downloadDirectory = ${OTHERCOMPLETEDIR}%" \
      "${N2MBASE}/autoProcessMedia.cfg"

   if [ ! -z "${COUCHPOTATOENABLED}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure nzbToMedia CouchPotato settings"
      sed -i \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%enabled = .*%enabled = 1%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%apikey =.*%apikey = ${GLOBALAPIKEY}%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%host =.*%host = openvpnpia%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%port =.*%port = 5050%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%ssl =.*%ssl = 1%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%web_root =.*%web_root = /couchpotato%" \
         "${N2MBASE}/autoProcessMedia.cfg"
   fi
   if [ ! -z "${SICKGEARENABLED}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure nzbToMedia SickGear settings"
      sed -i \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%enabled = .*%enabled = 1%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%apikey =.*%apikey = ${GLOBALAPIKEY}%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%host =.*%host = openvpnpia%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%port =.*%port = 8081%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%ssl =.*%ssl = 1%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%fork =.*%fork = sickgear%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%web_root =.*%web_root = /sickgear%" \
         "${N2MBASE}/autoProcessMedia.cfg"
   fi
   if [ ! -z "${HEADPHONESENABLED}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Configure nzbToMedia Headphones settings"
      sed -i \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%enabled = .*%enabled = 1%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%apikey =.*%apikey = ${GLOBALAPIKEY}%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%host =.*%host = openvpnpia%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%port =.*%port = 8181%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%ssl =.*%ssl = 1%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%web_root =.*%web_root = /headphones%" \
         "${N2MBASE}/autoProcessMedia.cfg"
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Correct owner and group of application files, if required"
   find "${N2MBASE}" ! -user "${STACKUSER}" -exec chown "${STACKUSER}" {} \;
   find "${N2MBASE}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${PYTHON_EGG_CACHE}" ! -user "${STACKUSER}" -exec chown "${STACKUSER}" {} \;
   find "${PYTHON_EGG_CACHE}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${CONFIGDIR}" ! -user "${STACKUSER}" -exec chown "${STACKUSER}" {} \;
   find "${CONFIGDIR}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${LOG_DIR}" ! -user "${STACKUSER}" -exec chown "${STACKUSER}" {} \;
   find "${LOG_DIR}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${PACKAGES}" ! -user "${STACKUSER}" -exec chown "${STACKUSER}" {} \;
   find "${PACKAGES}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
}

LaunchDeluge(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Starting Deluge daemon as ${STACKUSER}"
   su -pm "${STACKUSER}" -c "/usr/bin/deluged --config ${CONFIGDIR} --logfile ${LOG_DIR}/${LOG_DAEMON} --loglevel warning"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] Start Deluge webui as ${STACKUSER}"
   su "${STACKUSER}" -c "/usr/bin/deluge-web --config ${CONFIGDIR} --loglevel warning --do-not-daemonize"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${PID}] ***** Starting Deluge v${DELUGEVERSION} *****"
}

##### Script #####
Initialise
CreateGroup
CreateUser
if [ ! -f "${CONFIGDIR}/web.conf" ]; then FirstRun; fi
EnableSSL
Configure
InstallnzbToMedia
SetOwnerAndGroup
LaunchDeluge