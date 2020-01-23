#!/bin/ash

##### Functions #####
Initialise(){
   padding="    "
   program_id=$$
   program_id="${program_id:0:4}${padding:0:$((4 - ${#program_id}))}"
   log_dir="/var/tmp/deluge"
   log_file_name="deluge-daemon.log"
   deluge_version="$(usr/bin/deluge --version | grep deluge | awk '{print $2}')"
   python_major_version="$(python3 --version | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}')"
   python_packages="/usr/lib/python${python_major_version}/site-packages"
   nzb2media_repo="clinton-hall/nzbToMedia"
   nzb2media_base_dir="/nzbToMedia"
   lan_ip="$(hostname -i)"
   if [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** GeoIP Country database does not exist, waiting for it to be created ****"
      while [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; do
         sleep 2
      done
   fi
   echo -e "\n"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] ***** Starting Deluge v${deluge_version} *****"
   if [ ! -d "${PYTHON_EGG_CACHE}" ]; then mkdir "${PYTHON_EGG_CACHE}"; fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Local user: ${stack_user:=stackman}:${user_id:=1000}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Password: ${stack_password:=Skibidibbydibyodadubdub}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Local group: ${deluge_group:=deluge}:${deluge_group_id:=1000}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Movie complete directory: ${movie_complete_dir:=/storage/downloads/complete/movie/}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Music complete directory: ${music_complete_dir:=/storage/downloads/complete/music/}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] TV complete directory: ${tv_complete_dir:=/storage/downloads/complete/tv/}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Other downloads complete directory: ${other_complete_dir:=/storage/downloads/complete/other/}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Watch directory: ${deluge_watch_dir:=/storage/downloads/watch/deluge/}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Torrent file backup directory: ${deluge_file_backup_dir:=/storage/downloads/backup/deluge/}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Download directory: ${deluge_incoming_dir:=/storage/downloads/incoming/deluge/}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Download complete directory: ${download_complete_dir:=/storage/downloads/complete/}"
   deluge_abs_path_watch_dir="${deluge_watch_dir%/}"
}

CreateGroup(){
   if [ -z "$(getent group "${deluge_group}" | cut -d: -f3)" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Group ID available, creating group"
      addgroup -g "${deluge_group_id}" "${deluge_group}"
   elif [ ! "$(getent group "${deluge_group}" | cut -d: -f3)" = "${deluge_group_id}" ]; then
      echo "$(date '+%H:%M:%S') [ERROR   ][deluge.launcher.docker        :${program_id}] Group group_id mismatch - exiting"
      exit 1
   fi
}

CreateUser(){
   if [ -z "$(getent passwd "${stack_user}" | cut -d: -f3)" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] User ID available, creating user"
      adduser -s /bin/ash -D -G "${deluge_group}" -u "${user_id}" "${stack_user}"
   elif [ ! "$(getent passwd "${stack_user}" | cut -d: -f3)" = "${user_id}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] User ID already in use - exiting"
      exit 1
   fi
}

CreateLogFile(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Create log directory and daemon log file"
   mkdir -p "${log_dir}"
   touch "${log_dir}/${log_file_name}"
   chown -R "${stack_user}":"${deluge_group}" "${log_dir}"
}

FirstRun(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] ***** First run detected, creating configuration *****"
   find "${config_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${config_dir}" ! -group "${deluge_group}" -exec chgrp "${deluge_group}" {} \;
   if [ ! -f "${log_dir}/${log_file_name}" ]; then CreateLogFile; fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Starting Deluge daemon as ${stack_user} to generate default configuration"
   su "${stack_user}" -c "/usr/bin/deluged --config ${config_dir} --logfile ${log_dir}/${log_file_name} --loglevel none"
   sleep 5
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Enable AutoAdd, Blocklist, Execute, Label & Scheduler plugins"
   /usr/bin/deluge-console -U localclient -P "$(grep ^localclient ${config_dir}/auth | cut -d: -f2)" plugin --enable AutoAdd Blocklist Execute Label Scheduler
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Start Deluge webui as ${stack_user} to generate default configuration"
   su "${stack_user}" -c "/usr/bin/deluge-web --config ${config_dir} --loglevel none"
   sleep 10
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Stop Deluge daemon and webui to make configuration changes"
   pkill deluged
   pkill deluge-web
   sleep 5
   if [ -f "${config_dir}/session.state" ] && [ ! -f "${config_dir}/session.state.bak" ]; then
      cp -rp "${config_dir}/session.state" "${config_dir}/session.state.bak"
   fi
   daemon_user_id="$(grep -A2 hosts "${config_dir}/hostlist.conf" | tail -n1 | tr "[:upper:]" "[:lower:]" | sed 's/[^0-9a-f]*//g')"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Set default language to English to suppress error"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Disable first login option"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Enable web autoconnect to daemon"
   sed -i \
      -e "s%\"language\": \".*%\"language\": \"en_GB\",%" \
      -e "s%\"first_login\": .*%\"first_login\": false,%" \
      -e "s%\"default_daemon\": \".*%\"default_daemon\": \"${daemon_user_id}\",%" \
      "${config_dir}/web.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Set listening port to 57700"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Set outgoing port range to 58800-59900"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Set torrent backup location"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Ignore slow torrents"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Set download location"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Pre-allocate storage"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Prioritise first and last pieces"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Queue new to top"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Set completed download location"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Disable UPnP"
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
      "${config_dir}/core.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Enable plugins"
   sed -i \
      -e "/enabled_plugins/ s/^\(\s\+\)\(\"enabled_plugins\": \[\)\(\],\)/\1\2\n\1\3/" \
      "${config_dir}/web.conf"
   sed -i \
      -e "/enabled_plugins/a \"AutoAdd\"," \
      -e "/enabled_plugins/a \"Blocklist\"," \
      -e "/enabled_plugins/a \"Execute\"," \
      -e "/enabled_plugins/a \"Label\"," \
      -e "/enabled_plugins/a \"Scheduler\"" \
      "${config_dir}/web.conf"
   sed -i \
      -e "s/^\(\"AutoAdd\",\)/        \1/" \
      -e "s/^\(\"Blocklist\",\)/        \1/" \
      -e "s/^\(\"Execute\",\)/        \1/" \
      -e "s/^\(\"Label\",\)/        \1/" \
      -e "s/^\(\"Scheduler\"\)/        \1/" \
      "${config_dir}/web.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure Blocklist plugin"
   sed -i \
      -e "s%\"list_type\": .*%\"list_type\": \"SafePeer\",%" \
      -e "s%\"list_compression\": .*%\"list_compression\": \"GZip\",%" \
      -e "s%\"load_on_start\": .*%\"load_on_start\": true,%" \
      -e "s%\"url\": .*%\"url\": \"http://john.bitsurge.net/public/biglist.p2p.gz\",%" \
      "${config_dir}/blocklist.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure Execute plugin"
   sed -i \
      -e "s%\"\",%\"$(head /dev/urandom | tr -dc a-f0-9 | head -c40)\",%" \
      "${config_dir}/execute.conf"
   echo -e "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Set WebUI password to \x27${stack_password}\x27"
   password_sha1_hash="$(echo -n "$(grep pwd_salt ${config_dir}/web.conf | awk '{print $2}' | sed 's/[^[:alnum:]]//g')${stack_password}" | sha1sum | awk '{print $1}')"
   sed -i \
      -e "s%\"pwd_sha1\": \".*%\"pwd_sha1\": \"${password_sha1_hash}\",%" \
      "${config_dir}/web.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] ***** First run configuration complete *****"
}

EnableSSL(){
   if [ ! -d "${config_dir}/https" ]; then
      mkdir -p "${config_dir}/https"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Initialise HTTPS"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Generate server key"
      openssl ecparam -genkey -name secp384r1 -out "${config_dir}/https/deluge.key"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Generate certificate request"
      openssl req -new -subj "/C=NA/ST=Global/L=Global/O=Deluge/OU=Deluge/CN=Deluge/" -key "${config_dir}/https/deluge.key" -out "${config_dir}/https/deluge.csr"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Generate certificate"
      openssl x509 -req -sha256 -days 3650 -in "${config_dir}/https/deluge.csr" -signkey "${config_dir}/https/deluge.key" -out "${config_dir}/https/deluge.crt" >/dev/null 2>&1
   fi
   if [ -f "${config_dir}/https/deluge.key" ] && [ -f "${config_dir}/https/deluge.crt" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure Deluge to use HTTPS"
      sed -i \
         -e "s%\"pkey\": \".*%\"pkey\": \"${config_dir}\/https\/deluge.key\",%" \
         -e "s%\"cert\": \".*%\"cert\": \"${config_dir}\/https\/deluge.crt\",%" \
         -e "s%\"https\": .*%\"https\": true,%" \
         "${config_dir}/web.conf"
   fi
}

Configure(){
   sleep 5
   if [ ! -f "${log_dir}/${log_file_name}" ]; then CreateLogFile; fi
   if [  "$(ip a | grep tun. )" ]; then
      vpn_ip="$(ip a | grep tun.$ | awk '{print $2}')"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] VPN tunnel adapter detected, binding daemon to ${vpn_ip}"
   fi
   if [ "${vpn_ip}" ]; then
      vpn_adapter="$(ip a | grep tun.$ | awk '{print $7}')"
      sed -i \
         -e "s/\"listen_interface\": .*,/\"listen_interface\": \"${vpn_ip}\",/" \
         -e "s/\"outgoing_interface\": .*,/\"outgoing_interface\": \"${vpn_adapter}\",/" \
         "${config_dir}/core.conf"
   else
      echo "$(date '+%H:%M:%S') [ERROR   ][deluge.launcher.docker        :${program_id}] No VPN adapters present. Private connection not available. Exiting"
   fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Binding WebUI to ${lan_ip}"
   sed -i \
      -e "s%\"interface\": \".*%\"interface\": \"${lan_ip}\",%" \
      "${config_dir}/web.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure downloads path: ${deluge_incoming_dir}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure completed downloads path: ${download_complete_dir}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure torrent backup path: ${deluge_file_backup_dir}"
   sed -i \
      -e "s%\"download_location\": .*%\"download_location\": \"${deluge_incoming_dir}\",%" \
      -e "s%\"move_completed_path\": .*%\"move_completed_path\": \"${download_complete_dir}\",%" \
      -e "s%\"torrentfiles_location\": .*%\"torrentfiles_location\": \"${deluge_file_backup_dir}\",%" \
      "${config_dir}/core.conf"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure Labels plugin paths: ${movie_complete_dir}, ${music_complete_dir}, ${other_complete_dir} & ${tv_complete_dir}"
   sed -i \
      -e "/\"movie\": {$/,/},/ s/\"move_completed\": .*/\"move_completed\": true,/" \
      -e "/\"movie\": {$/,/},/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${movie_complete_dir}\",%" \
      -e "/\"music\": {$/,/},/ s/\"move_completed\": .*/\"move_completed\": true,/" \
      -e "/\"music\": {$/,/},/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${music_complete_dir}\",%" \
      -e "/\"other\": {$/,/},/ s/\"move_completed\": .*/\"move_completed\": true,/" \
      -e "/\"other\": {$/,/},/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${other_complete_dir}\",%" \
      -e "/\"tv\": {$/,/},/ s/\"move_completed\": .*/\"move_completed\": true,/" \
      -e "/\"tv\": {$/,/},/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${tv_complete_dir}\",%" \
      "${config_dir}/label.conf"
   deluge_label="movie"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure AutoAdd plugin for ${deluge_label} downloads"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure AutoAdd plugin base watch dir location: ${deluge_abs_path_watch_dir}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure AutoAdd plugin backup file location: ${deluge_file_backup_dir}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure AutoAdd plugin download location: ${deluge_incoming_dir}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure AutoAdd plugin movie watch location: ${deluge_watch_dir}${deluge_label}/"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure AutoAdd plugin completed download location: ${download_complete_dir}"
   sed -i \
      -e "/\"1\": {$/,/}/ s%\"label\": .*%\"label\": \"${deluge_label}\",%" \
      -e "/\"1\": {$/,/}/ s%\"path\": .*%\"path\": \"${deluge_watch_dir}${deluge_label}\/\",%" \
      -e "/\"1\": {$/,/}/ s%\"abspath\": .*%\"abspath\": \"${deluge_abs_path_watch_dir}\",%" \
      -e "/\"1\": {$/,/}/ s%\"copy_torrent\": .*%\"copy_torrent\": \"${deluge_file_backup_dir}\",%" \
      -e "/\"1\": {$/,/}/ s%\"download_location\": .*%\"download_location\": \"${deluge_incoming_dir}\",%" \
      -e "/\"1\": {$/,/}/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${download_complete_dir}\",%" \
      "${config_dir}/autoadd.conf"
}

InstallnzbToMedia(){
   if [ ! -d "${nzb2media_base_dir}" ]; then
      mkdir -p "${nzb2media_base_dir}"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] ${nzb2media_repo} not detected, installing..."
      chown "${stack_user}":"${deluge_group}" "${nzb2media_base_dir}"
      cd "${nzb2media_base_dir}"
      su "${stack_user}" -c "git clone --quiet --branch master https://github.com/${nzb2media_repo}.git ${nzb2media_base_dir}"
      if [ ! -f "${nzb2media_base_dir}/autoProcessMedia.cfg" ]; then
         cp "${nzb2media_base_dir}/autoProcessMedia.cfg.spec" "${nzb2media_base_dir}/autoProcessMedia.cfg"
      fi
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Change nzbToMedia default configuration"
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
         -e "/^\[General\]/,/^\[.*\]/ s%ffmpeg_path = *%ffmpeg_path = /usr/local/bin/ffmpeg%" \
         -e "/^\[General\]/,/^\[.*\]/ s%safe_mode =.*%safe_mode = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%no_extract_failed =.*%no_extract_failed = 1%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%clientAgent =.*%clientAgent = deluge%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%useLink =.*%useLink = move-sym%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%categories =.*%categories = tv, movie, music%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugeHost =.*%DelugeHost = 127.0.0.1%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugePort =.*%DelugePort = 58846%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugeUSR =.*%DelugeUSR = localclient%" \
         -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugePWD =.*%DelugePWD = $(grep ^localclient ${config_dir}/auth | cut -d: -f2)%" \
         "${nzb2media_base_dir}/autoProcessMedia.cfg"
   fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure nzbToMedia download paths"
   sed -i \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%outputDirectory =.*%outputDirectory = ${other_complete_dir}%" \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%default_downloadDirectory =.*%default_downloadDirectory = ${other_complete_dir}%" \
      "${nzb2media_base_dir}/autoProcessMedia.cfg"

   if [ "${couchpotato_enabled}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure nzbToMedia CouchPotato settings"
      sed -i \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%enabled = .*%enabled = 1%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%apikey =.*%apikey = ${global_api_key}%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%host =.*%host = openvpnpia%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%port =.*%port = 5050%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%ssl =.*%ssl = 1%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%web_root =.*%web_root = /couchpotato%" \
         "${nzb2media_base_dir}/autoProcessMedia.cfg"
   fi
   if [ "${sickgear_enabled}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure nzbToMedia SickGear settings"
      sed -i \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%enabled = .*%enabled = 1%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%apikey =.*%apikey = ${global_api_key}%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%host =.*%host = openvpnpia%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%port =.*%port = 8081%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%ssl =.*%ssl = 1%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%fork =.*%fork = sickgear%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%web_root =.*%web_root = /sickgear%" \
         "${nzb2media_base_dir}/autoProcessMedia.cfg"
   fi
   if [ "${headphones_enabled}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure nzbToMedia Headphones settings"
      sed -i \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%enabled = .*%enabled = 1%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%apikey =.*%apikey = ${global_api_key}%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%host =.*%host = openvpnpia%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%port =.*%port = 8181%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%ssl =.*%ssl = 1%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%web_root =.*%web_root = /headphones%" \
         "${nzb2media_base_dir}/autoProcessMedia.cfg"
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Correct owner and group of application files, if required"
   find "${nzb2media_base_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${nzb2media_base_dir}" ! -group "${deluge_group}" -exec chgrp "${deluge_group}" {} \;
   find "${PYTHON_EGG_CACHE}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${PYTHON_EGG_CACHE}" ! -group "${deluge_group}" -exec chgrp "${deluge_group}" {} \;
   find "${config_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${config_dir}" ! -group "${deluge_group}" -exec chgrp "${deluge_group}" {} \;
   find "${log_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${log_dir}" ! -group "${deluge_group}" -exec chgrp "${deluge_group}" {} \;
   find "${python_packages}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${python_packages}" ! -group "${deluge_group}" -exec chgrp "${deluge_group}" {} \;
}

LaunchDeluge(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Starting Deluge daemon as ${stack_user}"
   su -pm "${stack_user}" -c "/usr/bin/deluged --config ${config_dir} --logfile ${log_dir}/${log_file_name} --loglevel warning"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Start Deluge webui as ${stack_user}"
   su "${stack_user}" -c "/usr/bin/deluge-web --config ${config_dir} --loglevel warning --do-not-daemonize"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] ***** Starting Deluge v${deluge_version} *****"
}

##### Script #####
Initialise
CreateGroup
CreateUser
if [ ! -f "${config_dir}/web.conf" ]; then FirstRun; fi
EnableSSL
Configure
InstallnzbToMedia
SetOwnerAndGroup
