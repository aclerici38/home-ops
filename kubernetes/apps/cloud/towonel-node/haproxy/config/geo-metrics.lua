-- Counts geo-rejected (non-US) connections by source country and renders them
-- as Prometheus text. Counting happens via a tcp-request action on the reject
-- path (native cost is just one Lua call per blocked connection, which is tiny
-- at this volume); the series is only materialised when Prometheus scrapes.
--
-- State is per-worker and resets on reload (the weekly map refresh sends
-- SIGUSR2). That reads as a counter reset, which rate()/increase() handle.
--
-- The shared (non-per-thread) Lua state is guarded by HAProxy's global Lua
-- lock, so the table is safe to touch from multiple threads.

local geo_counts = {}

-- tcp-request content action: increment the blocked-country counter.
core.register_action("count_geo", { "tcp-req" }, function(txn)
  local c = txn:get_var("sess.country")
  if c == nil or c == "" then c = "XX" end
  geo_counts[c] = (geo_counts[c] or 0) + 1
end)

-- http service: render the counters in Prometheus exposition format.
core.register_service("geo_metrics", "http", function(applet)
  local lines = {
    "# HELP haproxy_geo_blocked_connections_total Non-US connections rejected by the geo-filter, by source country.",
    "# TYPE haproxy_geo_blocked_connections_total counter",
  }
  for country, n in pairs(geo_counts) do
    lines[#lines + 1] = string.format(
      'haproxy_geo_blocked_connections_total{country="%s"} %d', country, n)
  end
  local body = table.concat(lines, "\n") .. "\n"
  applet:set_status(200)
  applet:add_header("content-type", "text/plain; version=0.0.4")
  applet:add_header("content-length", string.len(body))
  applet:start_response()
  applet:send(body)
end)
