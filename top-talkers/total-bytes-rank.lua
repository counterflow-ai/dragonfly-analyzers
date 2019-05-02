-- ----------------------------------------------
-- Copyright (c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- Sort IP addresses by sum of total bytes sent and received

require 'analyzer/utils'

local hash_id = "total_bytes_rank"
local analyzer_name = 'Total Bytes Rank'

function setup()
    conn = hiredis.connect()
    if conn:command('PING') ~= hiredis.status.PONG then
        dragonfly.log_event(analyzer_name..': Could not connect to redis')
        dragonfly.log_event(analyzer_name..': exiting')
        os.exit()
    end
    starttime = 0 --mle.epoch()
    print (">>>>>>>>> Sum Bytes analyzer")
end

-- ----------------------------------------------
--
-- ----------------------------------------------
function loop(msg)
    local start = os.clock()
    local eve = msg
	local fields = {'ip_info.internal_ips',
                    ['proto'] = {'TCP','UDP'},
                    ['event_type'] = 'flow',}
    if not check_fields(eve, fields) then
        dragonfly.log_event(analyzer_name..': Required fields missing')
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end
        
    key = hash_id .. ":" ..eve.dest_ip

    local cmd = 'ZINCRBY '..hash_id ..':dest '..eve.flow.bytes_toclient..' '..eve.dest_ip
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    elseif not tonumber(reply) then
        dragonfly.log_event(analyzer_name..': Could not convert to number: '..reply)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end
    local dest_bytes = reply

    local cmd = 'ZINCRBY '..hash_id..':src '..eve.flow.bytes_toserver..' '..eve.src_ip
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    elseif not tonumber(reply) then
        dragonfly.log_event(analyzer_name..': Could not convert to number: '..reply)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end
    local src_bytes = reply

    local cmd = 'ZRANK '..hash_id..':dest '..eve.dest_ip
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    elseif not tonumber(reply) then
        dragonfly.log_event(analyzer_name..': Could not convert to number: '..reply)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end
    local dest_rank = reply

    local cmd = 'ZCARD '..hash_id .. ':dest'
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    elseif not tonumber(reply) then
        dragonfly.log_event(analyzer_name..': Could not convert to number: '..reply)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end
    local dest_size = reply

    local cmd = 'ZRANK '..hash_id..':src '..eve.src_ip 
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    elseif not tonumber(reply) then
        dragonfly.log_event(analyzer_name..': Could not convert to number: '..reply)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end
    local src_rank = reply

    local cmd = 'ZCARD '..hash_id .. ':src'
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    elseif not tonumber(reply) then
        dragonfly.log_event(analyzer_name..': Could not convert to number: '..reply)
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end
    local src_size = reply

    dest_percentile = tonumber(dest_rank) / tonumber(dest_size)
    dest_rank = tonumber(dest_size) - tonumber(dest_rank)
    src_percentile = (tonumber(src_rank) + 1) / tonumber(src_size)
    src_rank = tonumber(src_size) - tonumber(src_rank)


    analytics = eve.analytics
    if not analytics then
        analytics = {}
    end
    bytes_rank = {}
    bytes_rank["since"] = starttime
    bytes_rank["src_rank"] = tonumber(src_rank)
    bytes_rank["src_percentile"] = src_percentile
    bytes_rank["src_total"] = tonumber(src_bytes)
    bytes_rank["dest_rank"] = tonumber(dest_rank)
    bytes_rank["dest_percentile"] = dest_percentile
    bytes_rank["dest_total"] = tonumber(dest_bytes)
    bytes_rank["source"] = "ranked-sum.lua"

    analytics["bytes_rank"] = bytes_rank
    eve["analytics"] = analytics

    dragonfly.analyze_event(default_analyzer, eve)
    local now = os.clock()
    local delta = now - start
    dragonfly.log_event(analyzer_name..': time: '..delta)
end
