-- ----------------------------------------------
-- Copyright (c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- ----------------------------------------------
-- Invalid Certificate Count aggregates any TLS alerts using the Suricata rule set.
--  
-- Signature IDs pertaining to Invalid TLS range from 2230000 to 2230020
-- ----------------------------------------------

function setup()
    conn = hiredis.connect()
    assert(conn:command("PING") == hiredis.status.PONG)
    starttime = 0 --mle.epoch()
    print (">>>>>>>> Frequency Alert Triage")
    redis_key = "invalid_cert_count"
end

function loop(msg)
    local eve = msg
    if eve and eve.event_type == 'alert' and eve.alert.signature_id >= 2230000 and eve.alert.signature_id <= 2230020 then
        
        -- Found an invalid certificate, increment counts by IP
        local cmd = 'HINCRBY '..redis_key..':'..eve.src_ip..' total'..' 1'
        local reply = conn:command_line(cmd)
        if type(reply) == 'table' and reply.name ~= 'OK' then
            dragonfly.log_event(cmd..': '..reply.name)
            dragonfly.analyze_event(default_analyzer, msg)
            return
        end 
        src_count = reply

        local cmd = 'HINCRBY '..redis_key..':'..eve.dest_ip..' total'..' 1'
        local reply = conn:command_line(cmd)
        if type(reply) == 'table' and reply.name ~= 'OK' then
            dragonfly.log_event(cmd..': '..reply.name)
            dragonfly.analyze_event(default_analyzer, msg)
            return
        end 
        dest_count = reply

        src_type_count = update_cert_count(eve.src_ip, eve.alert.signature_id)
        if not src_type_count then 
            dragonfly.analyze_event(default_analyzer, msg)
            return
        end 

        dest_type_count = update_cert_count(eve.dest_ip, eve.alert.signature_id)
        if not dest_type_count then 
            dragonfly.analyze_event(default_analyzer, msg)
            return
        end 

        analytics = eve.analytics
        if not analytics then
            analytics = {}
        end

        invalid_cert = {}
        invalid_cert["src_total_invalid"] = src_count
        invalid_cert["dest_total_invalid"] = dest_count
        invalid_cert["src_type_count"] = src_type_count
        invalid_cert["dest_type_count"] = dest_type_count
        analytics["invalid_cert"] = invalid_cert
        eve["analytics"] = analytics
        dragonfly.analyze_event(default_analyzer, eve) 
    else 
        dragonfly.analyze_event(default_analyzer, msg)
    end
end

function update_cert_count(ip, sid)
    local cmd = 'HINCRBY '..redis_key .. ":" .. ip..' '..sid..' 1'
    reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
    dragonfly.log_event(cmd..' : '..reply.name)
        return nil
    end 
    return reply
end
