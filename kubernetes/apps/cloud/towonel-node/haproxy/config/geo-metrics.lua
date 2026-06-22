-- Counts every inbound connection by {country, action, sni} and renders the
-- totals as Prometheus text. Counting is one Lua call per connection (tiny at
-- this volume); the series is only materialised when Prometheus scrapes.
--
-- SNI is only recorded for allowed (US) traffic, whose label set is your own
-- served hostnames. Blocked traffic gets sni="" so scanner SNI spraying can't
-- explode cardinality. As a backstop against a US-source scanner spraying
-- random SNI, distinct series are capped (MAX_SERIES); beyond the cap, new SNIs
-- fold into an "other" bucket.
--
-- State is per-worker and resets on reload (the weekly map refresh sends
-- SIGUSR2). That reads as a counter reset, which rate()/increase() handle.
--
-- The shared (non-per-thread) Lua state is guarded by HAProxy's global Lua
-- lock, so the table is safe to touch from multiple threads.

local series = {} -- key -> { country=, action=, sni=, n= }
local distinct = 0
local MAX_SERIES = 2000

-- Second, independent metric family: approximate geolocation of accepted US
-- connections, keyed by {region, city, lat, lon}. Decoupled from the country/SNI
-- series above so city cardinality can't interact with SNI cardinality; capped
-- on its own (distinct US city centroids are a few thousand at most).
local geo = {} -- key -> { region=, city=, lat=, lon=, n= }
local geo_distinct = 0
local MAX_GEO_SERIES = 5000

local function bump(country, action, sni)
  local key = country .. "|" .. action .. "|" .. sni
  local s = series[key]
  if s == nil then
    -- Backstop: once at the cap, fold any new SNI into an "other" bucket.
    if distinct >= MAX_SERIES and sni ~= "" then
      key = country .. "|" .. action .. "|other"
      s = series[key]
      if s == nil then
        if distinct >= MAX_SERIES then return end
        s = { country = country, action = action, sni = "other", n = 0 }
        series[key] = s
        distinct = distinct + 1
      end
    else
      s = { country = country, action = action, sni = sni, n = 0 }
      series[key] = s
      distinct = distinct + 1
    end
  end
  s.n = s.n + 1
end

-- Record one accepted US connection at its approximate coordinates. geo_var is
-- the map_ip value "lat|lon|city|state" (empty/nil for an unmapped US IP, which
-- we drop since a point with no coordinates can't be placed on the map).
local function bump_geo(geo_var)
  if geo_var == nil or geo_var == "" then return end
  local lat, lon, city, region = geo_var:match("^([^|]*)|([^|]*)|([^|]*)|(.*)$")
  if lat == nil or lat == "" then return end
  local key = region .. "|" .. city .. "|" .. lat .. "|" .. lon
  local s = geo[key]
  if s == nil then
    if geo_distinct >= MAX_GEO_SERIES then return end
    s = { region = region, city = city, lat = lat, lon = lon, n = 0 }
    geo[key] = s
    geo_distinct = geo_distinct + 1
  end
  s.n = s.n + 1
end

-- tcp-request content action: count one connection.
core.register_action("count_conn", { "tcp-req" }, function(txn)
  local country = txn:get_var("sess.country")
  if country == nil or country == "" then country = "XX" end
  local action, sni
  if country == "US" then
    action = "allowed"
    sni = txn:get_var("sess.sni") or ""
    bump_geo(txn:get_var("sess.geo"))
  else
    action = "blocked"
    sni = ""
  end
  bump(country, action, sni)
end)

-- Prometheus label-value escaping (backslash, quote, newline).
local esc_map = { ["\\"] = "\\\\", ['"'] = '\\"', ["\n"] = "\\n" }
local function esc(s)
  return (s:gsub('[\\"\n]', esc_map))
end

-- http service: render the counters in Prometheus exposition format.
core.register_service("geo_metrics", "http", function(applet)
  local lines = {
    "# HELP haproxy_connections_total Inbound connections by source country, geo-filter action, and SNI (SNI only recorded for allowed traffic).",
    "# TYPE haproxy_connections_total counter",
  }
  for _, s in pairs(series) do
    lines[#lines + 1] = string.format(
      'haproxy_connections_total{country="%s",action="%s",sni="%s"} %d',
      s.country, s.action, esc(s.sni), s.n)
  end
  lines[#lines + 1] =
    "# HELP haproxy_geo_connections_total Accepted US connections by approximate geolocation (free GeoLite2-City; city placement is approximate)."
  lines[#lines + 1] = "# TYPE haproxy_geo_connections_total counter"
  for _, s in pairs(geo) do
    lines[#lines + 1] = string.format(
      'haproxy_geo_connections_total{region="%s",city="%s",lat="%s",lon="%s"} %d',
      esc(s.region), esc(s.city), esc(s.lat), esc(s.lon), s.n)
  end
  local body = table.concat(lines, "\n") .. "\n"
  applet:set_status(200)
  applet:add_header("content-type", "text/plain; version=0.0.4")
  applet:add_header("content-length", string.len(body))
  applet:start_response()
  applet:send(body)
end)
