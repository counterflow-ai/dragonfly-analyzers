-- ----------------------------------------------
-- Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
-- Author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- Routing code in an analyzer format

function setup()
	print (">>>>>>>> Router Filter")
end

-- ----------------------------------------------
--
-- ----------------------------------------------
function loop(msg)
    local eve = msg
    if eve then
        -- print(msg)
        if eve.event_type=="dns" then
            dragonfly.analyze_event("dga", msg)
        elseif eve.event_type == "alert" then
            dragonfly.analyze_event(default_analyzer, msg)
        elseif eve.event_type == "flow" then
            dragonfly.analyze_event("bytes_rank", msg)
        else
            dragonfly.analyze_event("sink", msg)
        end
    end
end