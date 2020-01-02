FROM alpine:latest
MAINTAINER boredazfcuk
ARG BUILDDEPENDENCIES="nano build-base g++ linux-headers autoconf cmake automake py3-pip"
ARG BUILDLIBRARIES="musl-dev python3-dev geoip-dev openssl-dev zlib-dev libffi-dev jpeg-dev"
ARG NZB2MEDIADEPENDENCIES="python3 git libgomp ffmpeg"
ARG DEPENDENCIES="tzdata libstdc++ geoip unrar unzip p7zip gettext zlib openssl"
ARG PIPDEPENDENCIES="geoip bencode ply slimit"
ARG N2MREPO="clinton-hall/nzbToMedia"
ARG PARREPO="Parchive/par2cmdline"
ARG BOOSTREPO="boostorg/boost"
ARG RASTERBARREPO="arvidn/libtorrent"
ARG BOOSTVERSIONOVERRIDE="1.71.0"
ARG BOOSTSRC="/tmp/boost/source"
ARG BOOSTENV="/tmp/boost/env"
ARG LIBTORRENTSRC="/tmp/libtorrent/source"
ARG DELUGESRC="/tmp/deluge/source"
ENV CONFIGDIR="/config" \
   PYTHON_EGG_CACHE="/config/.pythoneggcache"

RUN echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Create required directories" && \
   mkdir -pv "${BOOSTSRC}" "${BOOSTENV}" "${LIBTORRENTSRC}" "${DELUGESRC}" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install dependencies" && \
   apk add --no-cache ${DEPENDENCIES} && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install ${N2MREPO} dependencies" && \
   apk add --no-cache ${NZB2MEDIADEPENDENCIES} && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install build dependencies" && \
   apk add --no-cache --virtual=build-deps ${BUILDDEPENDENCIES} && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install build libraries" && \
   apk add --no-cache --virtual=build-libs ${BUILDLIBRARIES} && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install pip dependencies" && \
   pip3 install --no-cache-dir --upgrade pip ${PIPDEPENDENCIES} && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Create user python config" && \
   PYTHONINCLUDES="$(python3-config --includes | awk '{print $2}')" && \
   PYTHONINCLUDES="${PYTHONINCLUDES//-I/}" && \
   PYTHONMAJOR="$(python3 --version | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}')" && \
   echo -e "using gcc ;\nusing python : ${PYTHONMAJOR} : /usr/bin/python${PYTHONMAJOR} : ${PYTHONINCLUDES} : /usr/lib/python${PYTHONMAJOR} : ;" > ~/user-config.jam && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Download and extract boost" && \
   cd "${BOOSTSRC}" && \
   if [ ! -z "${BOOSTVERSIONOVERRIDE}" ]; then \
      BOOSTVERSION="${BOOSTVERSIONOVERRIDE}"; \
      BOOSTLATESTFILE="$(wget -qO- https://dl.bintray.com/boostorg/release/${BOOSTVERSION}/source/ | grep -v "rc" | grep -Eo '\".*\"' | grep -E '.*\.tar.gz\"' | sed 's/\"//g' | sort -r | head -n 1)"; \
   else \
      BOOSTVERSIONS="$(wget -qO- https://dl.bintray.com/boostorg/release/ | grep -v "rc" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -r | uniq)"; \
      while [ -z "${BOOSTLATESTFILE}" ]; do \
         BOOSTVERSION="$(echo "${BOOSTVERSIONS}" | head -n1)"; \
         BOOSTLATESTFILE="$(wget -qO- https://dl.bintray.com/boostorg/release/${BOOSTVERSION}/source/ | grep -v "rc" | grep -Eo '\".*\"' | grep -E '.*\.tar.gz\"' | sed 's/\"//g' | sort -r | head -n 1)"; \
         BOOSTVERSIONS="$(echo "${BOOSTVERSIONS}" | sed '1d')"; \
      done \
   fi && \
   BOOST_ROOT="${BOOSTSRC}/boost_${BOOSTVERSION//./_}" && \
   BOOST_BUILD_PATH="${BOOST_ROOT}/tools/build" && \
   wget -q "https://dl.bintray.com/boostorg/release/${BOOSTVERSION}/source/${BOOSTLATESTFILE}" && \
   tar xvf "${BOOSTSRC}/${BOOSTLATESTFILE}" -C "${BOOSTSRC}" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Stage boost-build" && \
   cd "${BOOST_BUILD_PATH}" && \
   ./bootstrap.sh && \
   OLDPATH="${PATH}" && \
   PATH="${PATH}:${BOOST_BUILD_PATH}" && \
   cd "${BOOST_ROOT}" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Stage boost libraries" && \
   ./bootstrap.sh --with-python="/usr/bin/python${PYTHONMAJOR}" --with-icu --with-libraries=chrono,date_time,python,random,system --prefix=/usr && \
   b2 install -j"$(nproc)" -sBOOST_ROOT="${BOOST_ROOT}" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Download and extract ${RASTERBARREPO}" && \
   cd "${LIBTORRENTSRC}" && \
   LIBTORRENTLATESTDOWNLOADURL="$(wget -qO- https://api.github.com/repos/arvidn/libtorrent/releases/latest | grep browser_download_url | grep ".tar" | awk -F'"' '{print $4}')" && \
   LIBTORRENTLATESTFILENAME="$(wget -qO- "https://api.github.com/repos/${RASTERBARREPO}/releases/latest" | grep name | tail -n1 | awk -F'"' '{print $4}')" && \
   wget -q "${LIBTORRENTLATESTDOWNLOADURL}" && \
   tar xvf "${LIBTORRENTSRC}/${LIBTORRENTLATESTFILENAME}" -C "${LIBTORRENTSRC}" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Build and install libtorrent libraries" && \
   cd "${LIBTORRENTSRC}/${LIBTORRENTLATESTFILENAME//\.tar\.gz/}" && \
   ./configure --enable-python-binding --with-libiconv --with-boost-python="boost_python${PYTHONMAJOR//./}" --prefix=/usr && \
   b2 release -sBOOST_ROOT="${BOOST_ROOT}" boost-link=shared dht=on encryption=on mutable-torrents=on crypto=openssl link=shared iconv=auto i2p=on extensions=on --prefix=/usr && \
   b2 install -j"$(nproc)" -sBOOST_ROOT="${BOOST_ROOT}" && \
   make -j"$(nproc)" && \
   make install && \
   cd "${LIBTORRENTSRC}/${LIBTORRENTLATESTFILENAME//\.tar\.gz/}/bindings/python" && \
   python3 setup.py build && \
   python3 setup.py install && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install Deluge" && \
   cd "${DELUGESRC}" && \
   git clone -b master git://deluge-torrent.org/deluge.git "${DELUGESRC}" && \
   pip3 install --no-cache-dir -r requirements.txt && \
   python3 setup.py build && \
   cd "${LIBTORRENTBUILD}" && \
   python3 setup.py install && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install ${PARREPO}" && \
   TEMP="$(mktemp -d)" && \
   git clone -b master "https://github.com/${PARREPO}.git" "${TEMP}" && \
   cd "${TEMP}" && \
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
   ln -s "/usr/bin/python${PYTHONMAJOR}" "/usr/bin/python" && \
   PATH="${OLDPATH}"

COPY start-deluge.sh /usr/local/bin/start-deluge.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY plugins/autoadd.conf "${CONFIGDIR}/autoadd.conf"
COPY plugins/execute.conf "${CONFIGDIR}/execute.conf"
COPY plugins/label.conf "${CONFIGDIR}/label.conf"

RUN echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on launcher script and create python link" && \
   chmod +x /usr/local/bin/start-deluge.sh /usr/local/bin/healthcheck.sh && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

HEALTHCHECK --start-period=30s --interval=1m --timeout=30s \
   CMD /usr/local/bin/healthcheck.sh

VOLUME "${CONFIGDIR}"

CMD /usr/local/bin/start-deluge.sh