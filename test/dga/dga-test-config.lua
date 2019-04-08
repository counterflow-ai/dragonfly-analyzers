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
   { tag="eve", uri="file:///usr/local/mle-data/dga-test-data.json", script="internal-ip.lua", default_analyzer="score"},
}

-- -----------------------------------------------------------
-- Analyzer queues/processors
-- -----------------------------------------------------------
analyzers = {
   { tag="score", script="dga-lr-mle.lua", default_analyzer="alert", default_output="debug" },
   { tag="alert", script="alert-dns-cache.lua" , default_analyzer="sink", default_output="debug"},
   { tag="sink", script="write-to-log.lua" , default_analyzer="", default_output="log"},
}

-- -----------------------------------------------------------
-- Output queues/processors
-- -----------------------------------------------------------
outputs = {
    { tag="log", uri="file://dragonfly-dga-test.log"},
    { tag="debug", uri="file://dragonfly-dga-test-debug.log"},
}

