-- ----------------------------------------------
-- Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
-- Author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- ---------------------------------
-- Enables configuration of output from the config file
-- ---------------------------------


function setup()
    print (">>>>>>>> Log Sink")
end

local analyzer_name = 'Write to Log'

function loop(msg)
    if msg then
        local eve = msg
        if eve then
            local output_time = os.time()
            local ingest_time = eve['dragonfly_ingest_timestamp_unix']
            if ingest_time then
                local latency = output_time - ingest_time
                eve['dragonfly_latency'] = latency
            end
            eve['dragonfly_output_timestamp_unix'] = output_time
            eve['dragonfly_output_timestamp'] = os.date("!%Y-%m-%dT%TZ")
            dragonfly.output_event(default_output, eve)
        else
            dragonfly.output_event(default_output, msg)
        end
    else
        dragonfly.output_event(default_output, msg)
    end
end
