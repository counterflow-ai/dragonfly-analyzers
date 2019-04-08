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
   { tag="eve", uri="file:///usr/local/mle-data/hll-test-data.json", script="internal-ip.lua", default_analyzer="hll"},
}

-- -----------------------------------------------------------
-- Analyzer queues/processors
-- -----------------------------------------------------------
analyzers = {
   { tag="hll", script="connection-count-hll.lua", default_analyzer="sink", default_output="debug" },
   { tag="sink", script="write-to-log.lua" , default_analyzer="", default_output="log"},
}

-- -----------------------------------------------------------
-- Output queues/processors
-- -----------------------------------------------------------
outputs = {
    { tag="log", uri="file://dragonfly-hll-test.log"},
    { tag="debug", uri="file://dragonfly-hll-test-debug.log"},
}

