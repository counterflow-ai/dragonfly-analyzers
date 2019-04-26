-- ----------------------------------------------
-- Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
-- author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------


-- ----------------------------------------------
-- Input processor for EVE log
-- DNS requests are processed, all other events go directly to the output
-- ----------------------------------------------

-- ----------------------------------------------
--
-- ----------------------------------------------
function setup()
	print ("DGA filter running")
end

-- ----------------------------------------------
--
-- ----------------------------------------------
function loop(msg)
    local eve = msg
    if eve.event_type=="dns" then
        dragonfly.analyze_event(default_analyzer, msg)
    else
        dragonfly.analyze_event("sink", msg)
    end
end