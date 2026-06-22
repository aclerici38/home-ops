#!/bin/sh
# Periodically rebuild the geoip map and gracefully reload HAProxy.
set -eu
: "$${REFRESH_INTERVAL:=604800}"   # weekly
while true; do
  sleep "$REFRESH_INTERVAL"
  echo "refreshing geoip map..."
  if /bin/sh /scripts/build-geoip-map.sh; then
    # Lowest-PID haproxy process == the master (workers are forked later and
    # keep higher PIDs across reloads). SIGUSR2 = graceful reload (-sf),
    # existing connections drain. Requires shareProcessNamespace + same uid.
    pid="$(pgrep haproxy | sort -n | head -1 || true)"
    if [ -n "$pid" ]; then
      kill -USR2 "$pid" && echo "sent SIGUSR2 to haproxy master pid $pid"
    else
      echo "WARN: haproxy master not found; map updated but not reloaded" >&2
    fi
  else
    echo "WARN: geoip refresh failed; keeping existing map" >&2
  fi
done
