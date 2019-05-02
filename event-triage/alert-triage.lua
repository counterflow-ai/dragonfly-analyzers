-- ----------------------------------------------
-- Copyright (c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- Uses a TF-IDF strategy for ranking alerts

require 'math'  
local main_key = "alert_triage"


function setup()
    conn = hiredis.connect()
    assert(conn:command("PING") == hiredis.status.PONG)
    starttime = 0 --mle.epoch()
    print (">>>>>>>> Frequency Alert Triage")
end

function loop(msg)
    local eve = msg
    if eve and eve.event_type == 'alert' then
        target = eve.dest_ip
        sid = eve.alert.signature_id
        -- classtype = eve.classtype ## Not in the Alert, need to look up in rules archive

        local cmd = 'INCR '..main_key..':'..sid..':'..target
        local reply = conn:command_line(cmd) -- Term Frequency, number times this alert fired on this target
        if type(reply) == 'table' and reply.name ~= 'OK' then
            dragonfly.log_event(cmd..' : '..reply.name)
            dragonfly.analyze_event(msg)
            return
        end
        local tf = reply

        local cmd = 'INCR '..main_key..':'..target
        local reply = conn:command(cmd)  -- 'Document' Length, total number of alerts on this target
        if type(reply) == 'table' and reply.name ~= 'OK' then
            dragonfly.log_event(cmd..' : '..reply.name)
            dragonfly.analyze_event(msg)
            return
        end
        local dt = reply

        local cmd = 'SADD '..main_key..':targets:'..sid..' '..target
        reply = conn:command_line(cmd) --Update unique set of target_ips with this alert
        if type(reply) == 'table' and reply.name ~= 'OK' then
            dragonfly.log_event(cmd..' : '..reply.name)
        end

        local cmd = 'SCARD '..main_key..':targets:'..sid
        local reply = conn:command_line(cmd)
        if type(reply) == 'table' then
            dragonfly.log_event(reply.name)
            dragonfly.analyze_event(msg)
            return
        end
        local nt = reply

        local cmd = 'SADD '..main_key..':targets '..target
        local reply = conn:command(cmd) -- Update total number of targets observed
        if type(reply) == 'table' and reply.name ~= 'OK' then
            dragonfly.log_event(cmd..' : '..reply.name)
        end

        local cmd = 'SCARD '..main_key..':targets'
        local reply = conn:command_line(cmd)
        if type(reply) == 'table' then
            dragonfly.log_event(reply.name)
            dragonfly.analyze_event(msg)
            return
        end
        local n = reply

        if not tonumber(tf) or not tonumber(dt) or not tonumber(n) or not tonumber(nt) then
            dragonfly.analyze_event(msg)
            return
        end

        -- Using default formula from Wikipedia TF-IDF
        tfidf = (tf/(dt * 1.0)) * math.log(1.0 + n/(nt * 1.0))
        -- Updated formula that does not normalize for document length (dt)
        -- tfidf = tf * math.log(1.0 + n/(nt * 1.0))

        analytics = eve.analytics
        if not analytics then
            analytics = {}
        end

        triage = {}
        triage["weight"] = tfidf
        triage["alert_count"] = tf
        triage["alerts_per_target"] = dt
        triage["unique_targets"] = nt
        triage["active_network_hosts"] = n
        analytics["triage"] = triage
        eve["analytics"] = analytics
        dragonfly.analyze_event(default_analyzer, eve) 
    else 
        dragonfly.analyze_event("sink", msg)
    end
end
