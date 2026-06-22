#!/bin/sh
# Build two HAProxy geoip maps from MaxMind GeoLite2 CSV editions:
#
#   geoip-country.map  CIDR -> ISO country code   (all countries; coarse blocks)
#       Used for the L4 geo reject and the country/SNI metric. Stays small.
#
#   geoip-uscity.map   CIDR -> "lat|lon|city|state"   (US networks only)
#       Used to enrich accepted US connections with approximate coordinates for
#       the geo metric. Built from the fine-grained City blocks but filtered to
#       US, so the tree stays a few hundred MB rather than tens of millions of
#       worldwide rows. City placement is free-tier accurate (state-good,
#       city-approximate); the value carries lat|lon for a coords geomap.
set -eu
MAPDIR=/etc/haproxy/maps
COUNTRY_MIN=100000   # floor for a sane country map (all countries, coarse blocks)
USCITY_MIN=200000    # floor for a sane US-city map (US networks only)

# --if-missing (init container): the maps live on a persistent volume, so if a
# valid pair is already present, reuse it and skip the download/build entirely —
# a pod restart then starts fast and offline. The weekly updater calls this
# script with no flag and always rebuilds. A persisted-but-truncated map (below
# the floors above) is treated as missing and rebuilt.
if [ "$${1:-}" = "--if-missing" ] \
   && [ -f "$MAPDIR/geoip-country.map" ] && [ -f "$MAPDIR/geoip-uscity.map" ]; then
  have_c="$(wc -l < "$MAPDIR/geoip-country.map")"
  have_u="$(wc -l < "$MAPDIR/geoip-uscity.map")"
  if [ "$have_c" -ge "$COUNTRY_MIN" ] && [ "$have_u" -ge "$USCITY_MIN" ]; then
    echo "existing maps present (country=$have_c uscity=$have_u entries), skipping build"
    exit 0
  fi
  echo "existing maps below floor (country=$have_c uscity=$have_u), rebuilding" >&2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

dl() { # <edition_id> -> downloads + unzips into $WORK/<edition>_*/
  cd "$WORK"
  echo "downloading $1..."
  i=1
  while [ "$i" -le 3 ]; do
    if wget -q -T 30 -O "$1.zip" \
      "https://download.maxmind.com/app/geoip_download?edition_id=$1&license_key=$${MAXMIND_LICENSE_KEY}&suffix=zip"; then
      break
    fi
    echo "  download of $1 failed (attempt $i/3), retrying..." >&2
    i=$((i + 1))
    sleep 5
  done
  [ "$i" -le 3 ] || { echo "ERROR: giving up on $1 after 3 attempts" >&2; return 1; }
  unzip -q "$1.zip"
}

# --- Country map (coarse, all countries): CIDR -> ISO --------------------------
# Pass 1: Locations CSV -> geoname_id => ISO country code (field 5).
# Pass 2+: Blocks CSVs -> emit "<network> <ISO>" using the block's country
#          geoname_id (field 2), falling back to registered country (field 3).
dl GeoLite2-Country-CSV
cd "$WORK"/GeoLite2-Country-CSV_*/
awk -F, '
  FNR==NR { if (FNR>1 && $5!="") iso[$1]=$5; next }
  FNR>1 {
    gid=$2; if (gid=="") gid=$3
    if (gid in iso && $1!="") print $1, iso[gid]
  }
' GeoLite2-Country-Locations-en.csv \
  GeoLite2-Country-Blocks-IPv4.csv \
  GeoLite2-Country-Blocks-IPv6.csv > "$WORK/country.new"

# --- US city map (fine blocks, US only): CIDR -> lat|lon|city|state ------------
# Pass 1: Locations CSV (quote-aware) -> US geoname_id => "city|state".
#         City/state names are free text and may contain quoted commas, so the
#         Locations file needs a real CSV parser (the Blocks files don't: their
#         fields are numeric/IDs, so a plain comma split is safe and fast).
# Pass 2+: Blocks CSVs -> for US geonames, emit "<network> lat|lon|city|state"
#          (lat=field 8, lon=field 9; geoname_id=field 2).
dl GeoLite2-City-CSV
cd "$WORK"/GeoLite2-City-CSV_*/
awk '
  function csv(line,   i,ch,inq,cur) {   # parse RFC4180-ish CSV into arr[1..]
    delete arr; ac=1; inq=0; cur=""
    for (i=1; i<=length(line); i++) {
      ch=substr(line,i,1)
      if (inq) {
        if (ch=="\"") { if (substr(line,i+1,1)=="\"") {cur=cur "\""; i++} else inq=0 }
        else cur=cur ch
      } else if (ch=="\"") { inq=1 }
      else if (ch==",") { arr[ac]=cur; ac++; cur="" }
      else cur=cur ch
    }
    arr[ac]=cur
  }
  FNR==NR {
    if (FNR>1) {
      csv($0)
      # 1=geoname_id 5=country_iso 7=subdivision_1_iso 11=city_name
      if (arr[5]=="US" && arr[1]!="") loc[arr[1]]=arr[11] "|" arr[7]
    }
    next
  }
  FNR>1 {
    split($0, b, ",")           # 1=network 2=geoname_id 8=latitude 9=longitude
    if (b[1]!="" && b[8]!="" && (b[2] in loc)) print b[1], b[8] "|" b[9] "|" loc[b[2]]
  }
' GeoLite2-City-Locations-en.csv \
  GeoLite2-City-Blocks-IPv4.csv \
  GeoLite2-City-Blocks-IPv6.csv > "$WORK/uscity.new"

cd "$WORK"

# Sanity check before swapping in — never install a truncated/empty map. A bad
# country map defaults everything to XX and rejects all traffic; a bad US-city
# map just blanks the geo metric, but a tiny one still signals a broken build.
clines="$(wc -l < country.new)"
ulines="$(wc -l < uscity.new)"
if [ "$clines" -lt "$COUNTRY_MIN" ]; then
  echo "ERROR: country map only $clines entries, refusing to install" >&2
  exit 1
fi
if [ "$ulines" -lt "$USCITY_MIN" ]; then
  echo "ERROR: us-city map only $ulines entries, refusing to install" >&2
  exit 1
fi

mv country.new "$MAPDIR/geoip-country.map"
mv uscity.new "$MAPDIR/geoip-uscity.map"
echo "installed maps: country=$clines uscity=$ulines entries"
