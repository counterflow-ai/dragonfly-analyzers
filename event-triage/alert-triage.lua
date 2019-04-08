-- ----------------------------------------------
-- Copyright 2018, CounterFlow AI, Inc. 
-- 
-- Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following 
-- conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer 
--    in the documentation and/or other materials provided with the distribution.
-- 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products 
--    derived from this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
-- BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
-- SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
-- OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- author: Andrew Fast <af@counterflowai.com>
-- ----------------------------------------------
require 'math'  
local main_key = "alert_triage"


function setup()
    conn = hiredis.connect()
    assert(conn:command("PING") == hiredis.status.PONG)
    starttime = 0 --mle.epoch()
    print (">>>>>>>> Frequency Alert Triage")
end

function loop(msg)
    local eve = cjson.decode(msg)
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
        dragonfly.analyze_event(default_analyzer, cjson.encode(eve)) 
    else 
        dragonfly.analyze_event("sink", msg)
    end
end
