FROM alpine:latest
MAINTAINER boredazfcuk
ENV BUILDDEPENDENCIES="nano build-base g++ linux-headers autoconf cmake automake py3-pip" \
   BUILDLIBRARIES="musl-dev python3-dev geoip-dev openssl-dev zlib-dev libffi-dev jpeg-dev" \
   NZB2MEDIADEPENDENCIES="python3 git libgomp ffmpeg" \
   DEPENDENCIES="tzdata libstdc++ geoip unrar unzip p7zip gettext zlib openssl" \
   PIPDEPENDENCIES="geoip bencode ply slimit" \
   CONFIGDIR="/config" \
   PYTHON_EGG_CACHE="/config/.pythoneggcache" \
   N2MBASE="/nzbToMedia" \
   N2MREPO="clinton-hall/nzbToMedia" \
	PARREPO="Parchive/par2cmdline" \
   BOOSTREPO="boostorg/boost" \
   RASTERBARREPO="arvidn/libtorrent" \
   BOOSTSRC="/tmp/boost/source" \
   BOOSTENV="/tmp/boost/env" \
   LIBTORRENTSRC="/tmp/libtorrent/source" \
   DELUGESRC="/tmp/deluge/source"

COPY start-deluge.sh /usr/local/bin/start-deluge.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

RUN echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Create required directories" && \
   mkdir -pv "${BOOSTSRC}" "${BOOSTENV}" "${LIBTORRENTSRC}" "${DELUGESRC}" "${N2MBASE}" && \
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
   BOOSTLATEST="$(wget -qO- https://dl.bintray.com/boostorg/release/ | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -r | head -n 1)" && \
   BOOST_ROOT="${BOOSTSRC}/boost_${BOOSTLATEST//./_}" && \
   BOOST_BUILD_PATH="${BOOST_ROOT}/tools/build" && \
   wget -q "https://dl.bintray.com/boostorg/release/${BOOSTLATEST}/source/boost_${BOOSTLATEST//./_}.tar.gz" && \
   tar xvf "${BOOSTSRC}/boost_${BOOSTLATEST//./_}.tar.gz" -C "${BOOSTSRC}" && \
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
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on launcher script and create python link" && \
   chmod +x /usr/local/bin/start-deluge.sh /usr/local/bin/healthcheck.sh && \
   ln -s "/usr/bin/python${PYTHONMAJOR}" "/usr/bin/python" && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | Install Clean Up" && \
   apk del --purge --no-progress build-deps build-libs && \
   pip3 uninstall -y ply slimit && \
   rm -rv /tmp/* ~/user-config.jam && \
   PATH="${OLDPATH}" && \
   unset BOOSTREPO BOOSTSRC BOOSTENV DELUGESRC PIPDEPENDENCIES DEPENDENCIES PIP3DEPENDENCIES PARREPO NZB2MEDIADEPENDENCIES BUILDLIBRARIES BUILDDEPENDENCIES LIBTORRENTSRC RASTERBARREPO OLDPATH && \
echo -e "\n$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
   CMD /usr/local/bin/healthcheck.sh

VOLUME "${CONFIGDIR}" "/shared"

CMD /usr/local/bin/start-deluge.sh