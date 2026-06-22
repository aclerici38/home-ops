#!/bin/sh
# Periodically rebuild the geoip map and gracefully reload HAProxy.
set -eu
: "$${REFRESH_INTERVAL:=604800}"   # weekly
while true; do
  sleep "$REFRESH_INTERVAL"
  echo "refreshing geoip map..."
  if /bin/sh /scripts/build-geoip-map.sh; then
    if echo "reload" | socat -t5 - UNIX-CONNECT:/run/haproxy/master.sock; then
      echo "requested haproxy reload"
    else
      echo "haproxy reload requested (master closed the CLI socket on re-exec)"
    fi
  else
    echo "WARN: geoip refresh failed; keeping existing map" >&2
  fi
done
