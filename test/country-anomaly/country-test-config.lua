-- ----------------------------------------------
-- Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
-- Author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- -----------------------------------------------------------
-- redis parameters
-- -----------------------------------------------------------
redis_host = "127.0.0.1"
redis_port = "6379"

-- -----------------------------------------------------------
-- Input queues/processors
-- -----------------------------------------------------------
inputs = {
   { tag="eve", uri="file:///usr/local/mle-data/country-test-data.json", script="country-test-filter.lua", default_analyzer="internal"},
}

-- -----------------------------------------------------------
-- Analyzer queues/processors
-- -----------------------------------------------------------
analyzers = {
   { tag="internal", script="internal-ip.lua", default_analyzer="geo", default_output="log" },
   { tag="geo", script="ip-geolocation.lua", default_analyzer="hist", default_output="log" },
   { tag="hist", script="country-anomaly.lua", default_analyzer="sink", default_output="debug" },
   { tag="sink", script="write-to-log.lua" , default_analyzer="", default_output="log"},
}

-- -----------------------------------------------------------
-- Output queues/processors
-- -----------------------------------------------------------
outputs = {
    { tag="log", uri="file://dragonfly-country-test.log"},
    { tag="debug", uri="file://dragonfly-country-test-debug.log"},
}

