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
    local eve = cjson.decode(msg)
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
        dragonfly.analyze_event(default_analyzer, cjson.encode(eve)) 
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
