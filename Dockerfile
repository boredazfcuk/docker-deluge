FROM alpine:latest
MAINTAINER boredazfcuk
ENV APPBASE="/Deluge" \
   BUILDDEPENDENCIES="curl gcc geoip-dev openssl-dev libffi-dev musl-dev python3-dev zlib-dev jpeg-dev" \
   RUNTIMEDEPENDENCIES="python3 tzdata py3-six py3-openssl geoip git" \
   CONFIGDIR="/config" \
   N2MBASE="/nzbToMedia" \
   N2MREPO="clinton-hall/nzbToMedia" \
   PYTHON_EGG_CACHE="/config/.pythoneggcache" \
   LOGDIR="/tmp" \
   LOG_DAEMON="deluge-daemon.log" \
   LOG_WEB="deluge-web.log"

COPY start-deluge.sh /usr/local/bin/start-deluge.sh

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Add group, user and directories" && \
   mkdir -p "${APPBASE}" "${N2MBASE}" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install build dependencies" && \
   apk add --no-cache --no-progress --virtual=build-deps ${BUILDDEPENDENCIES} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Deluge" && \
   pip3 install --no-cache-dir --upgrade pip && \
   pip3 install --no-cache-dir deluge geoip && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Deluge runtime dependencies" && \
   apk add --no-cache --no-progress ${RUNTIMEDEPENDENCIES} && \
   apk --repository "http://dl-cdn.alpinelinux.org/alpine/edge/main" add --no-cache --no-progress boost-python3 && \
   apk --repository "http://dl-cdn.alpinelinux.org/alpine/edge/testing" add --no-cache --no-progress py3-libtorrent-rasterbar && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install ${N2MREPO}" && \
   cd "${N2MBASE}" && \
   git clone -b master "https://github.com/${N2MREPO}.git" "${N2MBASE}" && \
   mkdir /shared && \
   touch "/shared/autoProcessMedia.cfg" && \
   ln -s "/shared/autoProcessMedia.cfg" "${N2MBASE}/autoProcessMedia.cfg" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on launcher script" && \
   chmod +x /usr/local/bin/start-deluge.sh && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Clean Up" && \
   apk del --purge --no-progress build-deps && \
   rm -r "/shared" /root/.cache/pip && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
   CMD wget --quiet --tries=1 --spider http://${HOSTNAME}:8112/ || exit 1

VOLUME "${CONFIGDIR}"

CMD /usr/local/bin/start-deluge.sh
