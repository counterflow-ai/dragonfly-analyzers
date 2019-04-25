-- -----------------------------------------------------------
-- Example config that shows file input processor error
-- -----------------------------------------------------------

-- -----------------------------------------------------------
-- redis parameters
-- -----------------------------------------------------------
redis_host = "127.0.0.1"
redis_port = "6379"

-- -----------------------------------------------------------
-- Input queues/processors
-- -----------------------------------------------------------
inputs = {
   { tag="eve", uri="file:///usr/local/mle-data/priority-test-data.json", script="priority-test-filter.lua", default_analyzer="time"}, --Split messages based on type
}

-- -----------------------------------------------------------
-- Analyzer queues/processors
-- -----------------------------------------------------------
analyzers = {
   { tag="time", script="time-anomaly.lua", default_analyzer="ip", default_output="log" },
   { tag="ip", script="internal-ip.lua", default_analyzer="router", default_output="log" },
   { tag="router", script="router-filter.lua", default_analyzer="blacklist", default_output="log" },
   { tag="dga", script="dga-lr-mle.lua", default_analyzer="sink", default_output="log" },
   { tag="bytes_rank",script="total-bytes-rank.lua",default_analyzer="sink", default_output="log" },
   { tag="blacklist", script="ip-blacklist.lua", default_analyzer="geo", default_output="log"},
   { tag="geo", script="ip-geolocation.lua", default_analyzer="country", default_output="log"},
   { tag="country", script="country-anomaly.lua", default_analyzer="cache", default_output="log"},
   { tag="cache", script="alert-dns-cache.lua", default_analyzer="signature", default_output="log" },
   { tag="signature", script="signature-anomaly.lua", default_analyzer="priority", default_output="log" },
   { tag="priority", script="overall-priority.lua", default_analyzer="sink", default_output="log"},
   { tag="sink", script="write-to-log.lua", default_analyzer="", default_output="log"},
}

-- -----------------------------------------------------------
-- Output queues/processors
-- -----------------------------------------------------------
outputs = {
    { tag="log", uri="file://dragonfly-priority-test.log"},
    { tag="debug", uri="file://debug.log"},
}

