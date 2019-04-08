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
   { tag="eve", uri="file:///usr/local/mle-data/internal-test-data.json", script="internal-test-filter.lua", default_analyzer="extract-internal-ip"},
}

-- -----------------------------------------------------------
-- Analyzer queues/processors
-- -----------------------------------------------------------
analyzers = {
   { tag="extract-internal-ip", script="internal-ip.lua", default_analyzer="sink", default_output="log" },
   { tag="sink", script="write-to-log.lua" , default_analyzer="", default_output="log"},
}

-- -----------------------------------------------------------
-- Output queues/processors
-- -----------------------------------------------------------
outputs = {
    { tag="log", uri="file://dragonfly-internal-test.log"},
}

