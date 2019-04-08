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
   { tag="eve", uri="file:///usr/local/mle-data/cache-test-data.json", script="cache-test-filter.lua", default_analyzer="dns"}, --Split messages based on type
}

-- -----------------------------------------------------------
-- Analyzer queues/processors
-- -----------------------------------------------------------
analyzers = {
   { tag="dns", script="dga-lr-mle.lua", default_analyzer="cache", default_output="log" },
   { tag="cache", script="alert-dns-cache.lua", default_analyzer="sink", default_output="log" },
   { tag="sink", script="write-to-log.lua" , default_analyzer="", default_output="log"},
}

-- -----------------------------------------------------------
-- Output queues/processors
-- -----------------------------------------------------------
outputs = {
    { tag="log", uri="file://dragonfly-cache-test.log"},
    { tag="debug", uri="file://debug.log"},
}

