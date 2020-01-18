FROM alpine:latest
MAINTAINER boredazfcuk
ARG build_dependencies="nano build-base g++ linux-headers autoconf cmake automake py3-pip"
ARG build_libraries="musl-dev python3-dev geoip-dev openssl-dev zlib-dev libffi-dev jpeg-dev"
ARG nzb2media_build_dependencies="python3 git libgomp ffmpeg"
ARG app_dependencies="tzdata libstdc++ geoip unrar unzip p7zip gettext zlib openssl"
ARG pip_dependencies="geoip bencode ply slimit"
ARG nzb2media_repo="clinton-hall/nzbToMedia"
ARG parchive_repo="Parchive/par2cmdline"
ARG boost_repo="boostorg/boost"
ARG rasterbar_repo="arvidn/libtorrent"
ARG boost_version_override="1.71.0"
ARG boost_source="/tmp/boost/source"
ARG boost_environment="/tmp/boost/env"
ARG libtorrent_source="/tmp/libtorrent/source"
ARG deluge_source="/tmp/deluge/source"
ENV config_dir="/config" \
   PYTHON_EGG_CACHE="/config/.pythoneggcache"

RUN echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Create required directories" && \
   mkdir -pv "${boost_source}" "${boost_environment}" "${libtorrent_source}" "${deluge_source}" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install dependencies" && \
   apk add --no-cache ${app_dependencies} && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install ${nzb2media_repo} dependencies" && \
   apk add --no-cache ${nzb2media_build_dependencies} && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install build dependencies" && \
   apk add --no-cache --virtual=build-deps ${build_dependencies} && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install build libraries" && \
   apk add --no-cache --virtual=build-libs ${build_libraries} && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install pip dependencies" && \
   pip3 install --no-cache-dir --upgrade pip ${pip_dependencies} && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Create user python config" && \
   python_includes="$(python3-config --includes | awk '{print $2}')" && \
   python_includes="${python_includes//-I/}" && \
   python_major_version="$(python3 --version | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}')" && \
   echo -e "using gcc ;\nusing python : ${python_major_version} : /usr/bin/python${python_major_version} : ${python_includes} : /usr/lib/python${python_major_version} : ;" > ~/user-config.jam && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Download and extract boost" && \
   cd "${boost_source}" && \
   if [ ! -z "${boost_version_override}" ]; then \
      boost_version="${boost_version_override}"; \
      boost_latest_file="$(wget -qO- https://dl.bintray.com/boostorg/release/${boost_version}/source/ | grep -v "rc" | grep -Eo '\".*\"' | grep -E '.*\.tar.gz\"' | sed 's/\"//g' | sort -r | head -n 1)"; \
   else \
      boost_versions="$(wget -qO- https://dl.bintray.com/boostorg/release/ | grep -v "rc" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -r | uniq)"; \
      while [ -z "${boost_latest_file}" ]; do \
         boost_version="$(echo "${boost_versions}" | head -n1)"; \
         boost_latest_file="$(wget -qO- https://dl.bintray.com/boostorg/release/${boost_version}/source/ | grep -v "rc" | grep -Eo '\".*\"' | grep -E '.*\.tar.gz\"' | sed 's/\"//g' | sort -r | head -n 1)"; \
         boost_versions="$(echo "${boost_versions}" | sed '1d')"; \
      done \
   fi && \
   boost_root_dir="${boost_source}/boost_${boost_version//./_}" && \
   boost_build_path="${boost_root_dir}/tools/build" && \
   wget -q "https://dl.bintray.com/boostorg/release/${boost_version}/source/${boost_latest_file}" && \
   tar xvf "${boost_source}/${boost_latest_file}" -C "${boost_source}" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Stage boost-build" && \
   cd "${boost_build_path}" && \
   ./bootstrap.sh && \
   old_path="${PATH}" && \
   PATH="${PATH}:${boost_build_path}" && \
   cd "${boost_root_dir}" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Stage boost libraries" && \
   ./bootstrap.sh --with-python="/usr/bin/python${python_major_version}" --with-icu --with-libraries=chrono,date_time,python,random,system --prefix=/usr && \
   b2 install -j"$(nproc)" -sBOOST_ROOT="${boost_root_dir}" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Download and extract ${rasterbar_repo}" && \
   cd "${libtorrent_source}" && \
   libtorrent_latest_download_url="$(wget -qO- https://api.github.com/repos/arvidn/libtorrent/releases/latest | grep browser_download_url | grep ".tar" | awk -F'"' '{print $4}')" && \
   libtorrent_latest_file_name="$(wget -qO- "https://api.github.com/repos/${rasterbar_repo}/releases/latest" | grep name | tail -n1 | awk -F'"' '{print $4}')" && \
   wget -q "${libtorrent_latest_download_url}" && \
   tar xvf "${libtorrent_source}/${libtorrent_latest_file_name}" -C "${libtorrent_source}" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Build and install libtorrent libraries" && \
   cd "${libtorrent_source}/${libtorrent_latest_file_name//\.tar\.gz/}" && \
   ./configure --enable-python-binding --with-libiconv --with-boost-python="boost_python${python_major_version//./}" --prefix=/usr && \
   b2 release -sBOOST_ROOT="${boost_root_dir}" boost-link=shared dht=on encryption=on mutable-torrents=on crypto=openssl link=shared iconv=auto i2p=on extensions=on --prefix=/usr && \
   b2 install -j"$(nproc)" -sBOOST_ROOT="${boost_root_dir}" && \
   make -j"$(nproc)" && \
   make install && \
   cd "${libtorrent_source}/${libtorrent_latest_file_name//\.tar\.gz/}/bindings/python" && \
   python3 setup.py build && \
   python3 setup.py install && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install Deluge" && \
   cd "${deluge_source}" && \
   git clone -b master git://deluge-torrent.org/deluge.git "${deluge_source}" && \
   pip3 install --no-cache-dir -r requirements.txt && \
   python3 setup.py build && \
   python3 setup.py install && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install ${parchive_repo}" && \
   temp_dir="$(mktemp -d)" && \
   git clone -b master "https://github.com/${parchive_repo}.git" "${temp_dir}" && \
   cd "${temp_dir}" && \
   aclocal && \
   automake --add-missing && \
   autoconf && \
   ./configure && \
   make && \
   make check && \
   make install && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install Clean Up" && \
   apk del --purge --no-progress build-deps build-libs && \
   pip3 uninstall -y ply slimit && \
   rm -rv /tmp/* ~/user-config.jam && \
   ln -s "/usr/bin/python${python_major_version}" "/usr/bin/python" && \
   PATH="${old_path}"

COPY start-deluge.sh /usr/local/bin/start-deluge.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY plugins/autoadd.conf "${config_dir}/autoadd.conf"
COPY plugins/execute.conf "${config_dir}/execute.conf"
COPY plugins/label.conf "${config_dir}/label.conf"

RUN echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on launcher script and create python link" && \
   chmod +x /usr/local/bin/start-deluge.sh /usr/local/bin/healthcheck.sh && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

HEALTHCHECK --start-period=30s --interval=1m --timeout=30s \
   CMD /usr/local/bin/healthcheck.sh

VOLUME "${config_dir}"

CMD /usr/local/bin/start-deluge.sh