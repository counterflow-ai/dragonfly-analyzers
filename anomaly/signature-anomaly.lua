-- ----------------------------------------------
-- Copyright(c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Collins Huff <ch@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
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
    local eve = msg
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
    dragonfly.analyze_event(default_analyzer, eve) 
    local now = os.clock()
    local delta = now - start
    dragonfly.log_event(analyzer_name..': time: '..delta)
end
