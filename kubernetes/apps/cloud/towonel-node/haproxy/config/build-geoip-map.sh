#!/bin/sh
# Build an HAProxy CIDR->ISO country map from MaxMind GeoLite2-Country-CSV.
set -eu
MAP=/etc/haproxy/maps/geoip-country.map
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

URL="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=$${MAXMIND_LICENSE_KEY}&suffix=zip"
echo "downloading GeoLite2-Country-CSV..."
wget -q -O db.zip "$URL"
unzip -q db.zip
cd GeoLite2-Country-CSV_*/

# Pass 1: Locations CSV -> geoname_id => ISO country code (field 5).
# Pass 2+: Blocks CSVs -> emit "<network> <ISO>" using the block's country
#          geoname_id (field 2), falling back to registered country (field 3).
awk -F, '
  FNR==NR { if (FNR>1 && $5!="") iso[$1]=$5; next }
  FNR>1 {
    gid=$2; if (gid=="") gid=$3
    if (gid in iso && $1!="") print $1, iso[gid]
  }
' GeoLite2-Country-Locations-en.csv \
  GeoLite2-Country-Blocks-IPv4.csv \
  GeoLite2-Country-Blocks-IPv6.csv > map.new

# Sanity check before swapping in — never install a truncated/empty map
# (which would default everything to XX and reject all traffic).
lines="$(wc -l < map.new)"
if [ "$lines" -lt 100000 ]; then
  echo "ERROR: only $lines entries, refusing to install map" >&2
  exit 1
fi
mv map.new "$MAP"
echo "installed geoip map: $lines entries"
