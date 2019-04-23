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
require 'analyzer/utils'
require 'analyzer/ip-utils'

local analyzer_name = 'Alert DNS Cache'

function setup()
    conn = hiredis.connect()
    if conn:command('PING') ~= hiredis.status.PONG then
        dragonfly.log_event(analyzer_name..': Could not connect to redis')
        dragonfly.log_event(analyzer_name..': exiting')
        os.exit()
    end
    starttime = 0 --mle.epoch()
    print('>>>>>>>> '..analyzer_name..' starting')
    dragonfly.log_event('>>>>>>>> '..analyzer_name..' starting')
end

function loop(msg)
    local start = os.clock()
    local eve = msg
	local fields = {"ip_info.internal_ips",
                    ["ip_info.internal_ip_code"] = {ip_internal_code.SRC,
                                                    ip_internal_code.DEST},
                    ["event_type"] = "alert",}
    if not check_fields(eve, fields) then
        dragonfly.log_event(analyzer_name..': Required fields missing')
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end

    local internal_ips = eve.ip_info.internal_ips
    local internal_ip_code = eve.ip_info.internal_ip_code
    local external_ip = get_external_ip(eve.src_ip, eve.dest_ip, internal_ip_code)
    if external_ip == nil then
        dragonfly.log_event(analyzer_name..': no external IPs')
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end

    analytics = eve.analytics
    if not analytics then
        analytics = {}
    end
    
    dga = {}
    dga['score'] = 0
    dga['domain'] = 'N/A'
    local cmd = 'GET dga:' .. external_ip
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
        analytics["dga"] = dga
        eve["analytics"] = analytics
        dragonfly.analyze_event(default_analyzer, eve) 
        return
    end

    score, domain = reply:match("(.+):(.+)") 
    if not score or not domain then
        dragonfly.log_event(analyzer_name..': Could not match score and domain: '.. reply)
        analytics["dga"] = dga
        eve["analytics"] = analytics
        dragonfly.analyze_event(default_analyzer, eve) 
        return
    end

    if not tonumber(score) then
        dragonfly.log_event(analyzer_name..': Could not convert to number: '.. score)
        analytics["dga"] = dga
        eve["analytics"] = analytics
        dragonfly.analyze_event(default_analyzer, eve) 
        return
    end

    dga["score"] = tonumber(score)
    dga["domain"] = domain
    analytics["dga"] = dga
    eve["analytics"] = analytics
    dragonfly.analyze_event(default_analyzer, eve) 
    local now = os.clock()
    local delta = now - start
    dragonfly.log_event(analyzer_name..': time: '..delta)
end
