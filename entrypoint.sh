#!/bin/ash

##### Functions #####
Initialise(){
   padding="    "
   program_id=$$
   program_id="${program_id:0:4}${padding:0:$((4 - ${#program_id}))}"
   deluge_version="$(usr/bin/deluge --version | grep deluge | awk '{print $2}')"
   python_version="$(python3 --version | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}')"
   libtorrent_version="$(python3 -c "import libtorrent; print (libtorrent.__version__)")"
   python_major_version="$(python3 --version | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}')"
   python_packages="/usr/lib/python${python_major_version}/site-packages"
   nzb2media_repo="clinton-hall/nzbToMedia"
   nzb2media_base_dir="/nzbToMedia"
   lan_ip="$(hostname -i)"
   log_dir="${config_dir}/logs"
   if [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** GeoIP Country database does not exist, waiting for it to be created ****"
      while [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; do
         sleep 2
      done
   fi
   echo
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] ***** Configuring Deluge container launch environment *****"
   if [ ! -d "${PYTHON_EGG_CACHE}" ]; then mkdir "${PYTHON_EGG_CACHE}"; fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] $(cat /etc/*-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/"//g')"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Deluge version: ${deluge_version}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Python version ${python_version}"
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] libtorrent-rasterbar version: ${libtorrent_version}"
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

CreateLogFiles(){
   if [ ! -d "${log_dir}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Create log directory: ${log_dir}"
      mkdir -p "${log_dir}"
      chown "${stack_user}":"${deluge_group}" "${log_dir}"
   fi
   if [ ! -f "${log_dir}/daemon.log" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Create daemon log file: ${log_dir}/daemon.log"
      touch "${log_dir}/daemon.log"
      chown "${stack_user}":"${deluge_group}" "${log_dir}/daemon.log"
   fi
   if [ ! -f "${log_dir}/web.log" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Create web log file: ${log_dir}/web.log"
      touch "${log_dir}/web.log"
      chown "${stack_user}":"${deluge_group}" "${log_dir}/web.log"
   fi
}

CreateDefaultDaemonConfig(){
   if [ ! -f "${config_dir}/core.conf" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] ***** First run detected, creating default configuration *****"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Starting Deluge daemon to generate default daemon configuration"
      /usr/bin/deluged --config "${config_dir}" --logfile "${log_dir}/daemon.log" --loglevel info
      sleep 10
      pkill deluged
      sleep 2
      pkill deluged
      sleep 2
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] ***** Creation of default daemon configuration complete *****"
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
   fi
}

CreateDefaultWebConfig(){
   if [ ! -f "${config_dir}/web.conf" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Start Deluge webui to generate default configuration"
      /usr/bin/deluge-web --config "${config_dir}" --logfile "${log_dir}/web.log" --loglevel info
      sleep 10
      pkill deluge-web
      sleep 2
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] ***** Creation of default daemon configuration complete *****"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Reload Deluge launch environment"
      daemon_user_id="$(grep -A2 hosts "${config_dir}/hostlist.conf" | tail -n1 | tr "[:upper:]" "[:lower:]" | sed 's/[^0-9a-f]*//g')"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Set default language to English to suppress error"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Disable first login option"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Enable web autoconnect to daemon"
      sed -i \
         -e "s%\"language\": \".*%\"language\": \"en_GB\",%" \
         -e "s%\"first_login\": .*%\"first_login\": false,%" \
         -e "s%\"show_session_speed\": .*%\"show_session_speed\": true,%" \
         -e "s%\"default_daemon\": \".*%\"default_daemon\": \"${daemon_user_id}\",%" \
         "${config_dir}/web.conf"
   fi
}

ConfigurePlugins(){
   if [ ! -d "${config_dir}/.pythoneggcache" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Starting Deluge daemon to install plugins"
      /usr/bin/deluged --config "${config_dir}" --logfile "${log_dir}/daemon.log" --loglevel info
      sleep 10
      if [ ! -d "${config_dir}/.pythoneggcache/AutoAdd*" ]; then
         echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Install AutoAdd plugin"
         /usr/bin/deluge-console -U localclient -P "$(grep ^localclient ${config_dir}/auth | cut -d: -f2)" plugin --enable AutoAdd
      fi
      if [ ! -d "${config_dir}/.pythoneggcache/Blocklist*" ]; then
         echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Install Blocklist plugin"
         /usr/bin/deluge-console -U localclient -P "$(grep ^localclient ${config_dir}/auth | cut -d: -f2)" plugin --enable Blocklist
         sleep 5
      fi
      if [ ! -d "${config_dir}/.pythoneggcache/Execute*" ]; then
         echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Install Execute plugin"
         /usr/bin/deluge-console -U localclient -P "$(grep ^localclient ${config_dir}/auth | cut -d: -f2)" plugin --enable Execute
      fi
      if [ ! -d "${config_dir}/.pythoneggcache/Label*" ]; then
         echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Install Label plugin"
         /usr/bin/deluge-console -U localclient -P "$(grep ^localclient ${config_dir}/auth | cut -d: -f2)" plugin --enable Label
      fi
      if [ ! -d "${config_dir}/.pythoneggcache/Scheduler*" ]; then
         echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Install Scheduler plugin"
         /usr/bin/deluge-console -U localclient -P "$(grep ^localclient ${config_dir}/auth | cut -d: -f2)" plugin --enable Scheduler
      fi
      sleep 10
      pkill deluged
      sleep 2
      pkill deluged
      sleep 2
   fi
   if [ "$(grep -c '\"enabled_plugins\": \[],' "${config_dir}/web.conf")" -eq 1 ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Enabled plugins onfigure plugins"
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
   fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure Blocklist plugin"
   sed -i \
      -e "s%\"list_type\": .*%\"list_type\": \"SafePeer\",%" \
      -e "s%\"load_on_start\": .*%\"load_on_start\": true,%" \
      -e "s%\"list_compression\": .*%\"list_compression\": \"GZip\",%" \
      -e "s%\"url\": .*%\"url\": \"http://john.bitsurge.net/public/biglist.p2p.gz\",%" \
      "${config_dir}/blocklist.conf"
   if [ "$(grep -c '\"\",' "${config_dir}/execute.conf")" -eq 1 ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure Execute plugin"
      sed -i \
         -e "s%\"\",%\"$(head /dev/urandom | tr -dc a-f0-9 | head -c40)\",%" \
         "${config_dir}/execute.conf"
   fi
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

SetCredentials(){
   echo -e "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Set daemon username \x27${stack_user}\x27 and password \x27${stack_password}\x27"
   if [ ! -f "${config_dir}/auth" ] || [ "$(grep -c "${stack_user}" "${config_dir}/auth")" = 0 ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] User does not exist, creating user ${stack_user}"
      echo "${stack_user}:${stack_password}:10" >> "${config_dir}/auth"
   else
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] User exists - checking credentials"
      current_password="$(grep "${stack_user}" "${config_dir}/auth" | cut -d':' -f2)"
      if [ "${current_password}" = "${stack_password}" ]; then
         echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] User credentials match"
      else
         echo "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${program_id}] User credentials do not match. Password for user has been changed. Removing invalid credentials"
         sed -i \
            -e "/${stack_user}/d" \
            "${config_dir}/web.conf"
         echo -e "$(date '+%H:%M:%S') [WARNING ][deluge.launcher.docker        :${program_id}] Adding user ${stack_user} with password \x27${stack_password}\x27"
         echo "${stack_user}:${stack_password}:10" >> "${config_dir}/auth"
      fi
   fi
   echo -e "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Set WebUI password to \x27${stack_password}\x27"
   stack_password_sha1_hash="$(echo -n "$(grep pwd_salt ${config_dir}/web.conf | awk '{print $2}' | sed 's/[^[:alnum:]]//g')${stack_password}" | sha1sum | awk '{print $1}')"
   sed -i \
      -e "s%\"pwd_sha1\": \".*%\"pwd_sha1\": \"${stack_password_sha1_hash}\",%" \
      "${config_dir}/web.conf"
}

Configure(){
   vpn_adapter="$(ip addr | grep tun.$ | awk '{print $7}')"
   if [ "${vpn_adapter}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] VPN tunnel adapter detected, setting outgoing adapter to ${vpn_adapter}"
      sed -i \
         -e "s/\"outgoing_interface\": .*,/\"outgoing_interface\": \"${vpn_adapter}\",/" \
         "${config_dir}/core.conf"
   else
      echo "$(date '+%H:%M:%S') [ERROR   ][deluge.launcher.docker        :${program_id}] No VPN adapters present. Private connection not available. Exiting"
      exit 1
   fi
   vpn_ip="$(ip addr | grep tun.$ | awk '{print $2}')"
   if [ "${vpn_ip}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] VPN tunnel IP address detected, setting listening interface to ${vpn_adapter}"
      sed -i \
         -e "s/\"listen_interface\": .*,/\"listen_interface\": \"${vpn_ip}\",/" \
         "${config_dir}/core.conf"
   fi
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Binding WebUI to ${lan_ip}"
   #echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Setting web root to /deluge/"
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
      -e "/\"movie\": {$/,/},/ s/\"apply_move_completed\": .*/\"apply_move_completed\": true,/" \
      -e "/\"movie\": {$/,/},/ s/\"move_completed\": .*/\"move_completed\": true,/" \
      -e "/\"movie\": {$/,/},/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${movie_complete_dir}\",%" \
      -e "/\"music\": {$/,/},/ s/\"apply_move_completed\": .*/\"apply_move_completed\": true,/" \
      -e "/\"music\": {$/,/},/ s/\"move_completed\": .*/\"move_completed\": true,/" \
      -e "/\"music\": {$/,/},/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${music_complete_dir}\",%" \
      -e "/\"other\": {$/,/},/ s/\"apply_move_completed\": .*/\"apply_move_completed\": true,/" \
      -e "/\"other\": {$/,/},/ s/\"move_completed\": .*/\"move_completed\": true,/" \
      -e "/\"other\": {$/,/},/ s%\"move_completed_path\": .*%\"move_completed_path\": \"${other_complete_dir}\",%" \
      -e "/\"tv\": {$/,/},/ s/\"apply_move_completed\": .*/\"apply_move_completed\": true,/" \
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
   if [ ! -f "${nzb2media_base_dir}/nzbToMedia.py" ]; then
      if [ -d "${nzb2media_base_dir}" ]; then
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Cleaning up previously failed installation"
         rm -r "${nzb2media_base_dir}"
      fi
      mkdir -p "${nzb2media_base_dir}"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] ${nzb2media_repo} not detected, installing..."
      chown "${stack_user}":"${deluge_group}" "${nzb2media_base_dir}"
      cd "${nzb2media_base_dir}"
      su "${stack_user}" -c "git clone --quiet --branch master https://github.com/${nzb2media_repo}.git ${nzb2media_base_dir}"
   fi
   if [ ! -f "${nzb2media_base_dir}/autoProcessMedia.cfg" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Creating autoProcessMedia.cfg file from default"
      cp "${nzb2media_base_dir}/autoProcessMedia.cfg.spec" "${nzb2media_base_dir}/autoProcessMedia.cfg"
   fi
}

ConfigurenzbToMedia(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure nzbToMedia general settings"
   sed -i \
      -e "/^\[General\]/,/^\[.*\]/ s%auto_update =.*%auto_update = 1%" \
      -e "/^\[General\]/,/^\[.*\]/ s%git_path =.*%git_path = /usr/bin/git%" \
      -e "/^\[General\]/,/^\[.*\]/ s%safe_mode =.*%safe_mode = 1%" \
      -e "/^\[General\]/,/^\[.*\]/ s%no_extract_failed =.*%no_extract_failed = 1%" \
      -e "/^\[General\]/,/^\[.*\]/ s%ffmpeg_path.*%ffmpeg_path = /usr/local/bin/ffmpeg%" \
      -e "/^\[General\]/,/^\[.*\]/ s%git_branch =.*%git_branch = master%" \
      "${nzb2media_base_dir}/autoProcessMedia.cfg"
}

N2MDeluge(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure nzbToMedia Deluge settings"
   sed -i \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%clientAgent =.*%clientAgent = deluge%" \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%useLink =.*%useLink = move%" \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%categories =.*%categories = tv, movie, music%" \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugeHost =.*%DelugeHost = 127.0.0.1%" \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugePort =.*%DelugePort = 58846%" \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugeUSR =.*%DelugeUSR = localclient%" \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%DelugePWD =.*%DelugePWD = $(grep ^localclient ${config_dir}/auth | cut -d: -f2)%" \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%outputDirectory =.*%outputDirectory = ${download_complete_dir}%" \
      -e "/^\[Torrent\]/,/^\[.*\]/ s%default_downloadDirectory =.*%default_downloadDirectory = ${other_complete_dir}%" \
      "${nzb2media_base_dir}/autoProcessMedia.cfg"
}

N2MCouchPotato(){
   if [ "${couchpotato_enabled}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure nzbToMedia CouchPotato settings"
      sed -i \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%enabled = .*%enabled = 1%" \
         -e "/^\[CouchPotato\]/,/###### ADVANCED USE/ s%apikey =.*%apikey = ${global_api_key}%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%host =.*%host = couchpotato%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%port =.*%port = 5050%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%ssl =.*%ssl = 1%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%web_root =.*%web_root = /couchpotato%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%minSize =.*%minSize = 3000%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%delete_failed =.*%delete_failed = 1%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%delete_ignored =.*%delete_ignored = 1%" \
         -e "/^\[CouchPotato\]/,/^\[.*\]/ s%watch_dir =.*%watch_dir = ${movie_complete_dir}%" \
         "${nzb2media_base_dir}/autoProcessMedia.cfg"
   fi
}

N2MSickGear(){
   if [ "${sickgear_enabled}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure nzbToMedia SickGear settings"
      sed -i \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%enabled = .*%enabled = 1%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%apikey =.*%apikey = ${global_api_key}%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%host =.*%host = sickgear%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%port =.*%port = 8081%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%ssl =.*%ssl = 1%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%fork =.*%fork = sickgear%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%web_root =.*%web_root = /sickgear%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%minSize =.*%minSize = 350%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%delete_failed =.*%delete_failed = 1%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%delete_ignored =.*%delete_ignored = 1%" \
         -e "/^\[SickBeard\]/,/^\[.*\]/ s%watch_dir =.*%watch_dir = ${tv_complete_dir}%" \
         "${nzb2media_base_dir}/autoProcessMedia.cfg"
   fi
}

N2MHeadphones(){
   if [ "${headphones_enabled}" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Configure nzbToMedia Headphones settings"
      sed -i \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%enabled = .*%enabled = 1%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%apikey =.*%apikey = ${global_api_key}%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%host =.*%host = headphones%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%port =.*%port = 8181%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%ssl =.*%ssl = 1%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%web_root =.*%web_root = /headphones%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%minSize =.*%minSize = 10%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%delete_failed =.*%delete_failed = 1%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%delete_ignored =.*%delete_ignored = 1%" \
         -e "/^\[HeadPhones\]/,/^\[.*\]/ s%watch_dir =.*%watch_dir = ${music_complete_dir}%" \
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
   find "${python_packages}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${python_packages}" ! -group "${deluge_group}" -exec chgrp "${deluge_group}" {} \;
}

LaunchDeluge(){
   echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] ***** Configuration of Deluge container launch environment complete *****"
   if [ -z "$1" ]; then
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Starting Deluge daemon as ${stack_user}"
      "$(which su)" -p "${stack_user}" -c "/usr/bin/deluged --config ${config_dir} --logfile ${log_dir}/daemon.log --loglevel info"
      echo "$(date '+%H:%M:%S') [INFO    ][deluge.launcher.docker        :${program_id}] Starting Deluge webui as ${stack_user}"
      "$(which su)" -p "${stack_user}" -c "/usr/bin/deluge-web --config ${config_dir} --logfile ${log_dir}/web.log --loglevel debug --do-not-daemonize"
   else
      exec "$@"
   fi
}

##### Script #####
Initialise
CreateGroup
CreateUser
CreateLogFiles
CreateDefaultDaemonConfig
CreateDefaultWebConfig
ConfigurePlugins
EnableSSL
SetCredentials
Configure
InstallnzbToMedia
ConfigurenzbToMedia
N2MDeluge
N2MCouchPotato
N2MSickGear
N2MHeadphones
SetOwnerAndGroup
LaunchDeluge