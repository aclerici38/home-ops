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

-- tcp-request content action: count one connection.
core.register_action("count_conn", { "tcp-req" }, function(txn)
  local country = txn:get_var("sess.country")
  if country == nil or country == "" then country = "XX" end
  local action, sni
  if country == "US" then
    action = "allowed"
    sni = txn:get_var("sess.sni") or ""
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
  local body = table.concat(lines, "\n") .. "\n"
  applet:set_status(200)
  applet:add_header("content-type", "text/plain; version=0.0.4")
  applet:add_header("content-length", string.len(body))
  applet:start_response()
  applet:send(body)
end)
