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
-- author: Collins Huff <ch@counterflowai.com>
-- ----------------------------------------------

-- Signature anomaly

require 'analyzer/utils'

local redis_key = "signature-id-count"
local analyzer_name = 'Signature anomaly'

function setup()
    conn = hiredis.connect()
    if conn:command('PING') ~= hiredis.status.PONG then
        dragonfly.log_event(analyzer_name..': Could not connect to redis')
        dragonfly.log_event(analyzer_name..': exiting')
        os.exit()
    end
    starttime = 0 --mle.epoch()
    local cmd = 'HMSET '..redis_key..' total 0'
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
    end 
    print (">>>>>>>> Signature Anomaly")
end


function loop(msg)
    local start = os.clock()
    local eve = cjson.decode(msg)
	local fields = {"alert.signature_id",}
    if not check_fields(eve, fields) then
        --dragonfly.log_event('Missing fields alert.signature_id')
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end

	local sig_id = eve.alert.signature_id
    local cmd = 'HINCRBY '..redis_key..' total 1'
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
		dragonfly.analyze_event(default_analyzer, msg)
        return
    end 
    local total = reply

    local cmd = 'HINCRBY '..redis_key..' '..sig_id..' 1'
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
		dragonfly.analyze_event(default_analyzer, msg)
        return
    end 
    local count = reply

    local cmd = 'HLEN '..redis_key
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
		dragonfly.analyze_event(default_analyzer, msg)
        return
    end 
    local unique_sigs = reply

    if not tonumber(total) or not tonumber(count) or not tonumber(unique_sigs) then
        dragonfly.log_event(analyzer_name..': Could not convert total '.. total..
                                           ' or count to number '..count.. 
                                           ' or unique_sigs '..unique_sigs)
		dragonfly.analyze_event(default_analyzer, msg)
        return
    end

    local count = tonumber(count)
    local total = tonumber(total)
    local unique_sigs = tonumber(unique_sigs) - 1

    local prob = count * 1.0 / total
    local inv_prob = 1 - prob
    local threshold = 1 - (1.0 / unique_sigs)

    analytics = eve.analytics
    if not analytics then
        analytics = {}
    end
    
    signature_info = {}
    signature_info["score"] = inv_prob
    signature_info["count"] = count
    signature_info["total"] = total
    signature_info["threshold"] = threshold
    signature_info["unique_signatures"] = unique_sigs
    analytics["signature"] = signature_info
    eve['analytics'] = analytics
    dragonfly.analyze_event(default_analyzer, cjson.encode(eve)) 
    local now = os.clock()
    local delta = now - start
    dragonfly.log_event(analyzer_name..': time: '..delta)
end
