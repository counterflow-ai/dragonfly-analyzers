-- ----------------------------------------------
-- Copyright (c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- ----------------------------------------------
-- example-hll.lua
-- Tracks number of distinct sources for each dest_ip using a HyperLogLog "sketch" data structure.
-- HyperLogLog is included in the base functionality of Redis. It is a set-like data structure
-- with constant memory and insert time, but that returns an approximate result with rate
-- tied to the size of the hash being used.
-- ----------------------------------------------

require 'analyzer/utils'
require 'analyzer/ip-utils'

local hash_id = "distinct_src_ip_counter"

-- ----------------------------------------------
--
-- ----------------------------------------------
function setup()
    conn = hiredis.connect()
    assert(conn:command("PING") == hiredis.status.PONG)
    starttime = 0 --mle.epoch()
    print (">>>>>>>>> Distinct IP analyzer")
end


-- ----------------------------------------------
--
-- ----------------------------------------------
function loop(msg)
    local eve = msg
	local fields = {"ip_info.internal_ips",
                    ["ip_info.internal_ip_code"] = {ip_internal_code.SRC,
                                                    ip_internal_code.DEST},
                    ['event_type'] = 'flow',
                    ['proto'] = {'TCP','UDP'},
                   }
    if not check_fields(eve, fields) then
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end

    local internal_ips = eve.ip_info.internal_ips
    local internal_ip_code = eve.ip_info.internal_ip_code
    local external_ip = get_external_ip(eve.src_ip, eve.dest_ip, internal_ip_code)
    if external_ip == nil then
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end

    internal_ip = internal_ips[1]

    key = hash_id .. ":" ..internal_ip
    local cmd = 'PFADD'..' '..key..' '..external_ip -- PFADD returns 1 if at least one internal register has altered.
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg) 
        return
    end 

    local cmd = 'PFCOUNT '..key
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg) 
        return
    end 
    local count = reply

    -- Create table to hold results of analysis, if it doesn't already exist
    analytics = eve.analytics
    if not analytics then
        analytics = {}
    end
    unique_src = {}
    unique_src["since"] = starttime
    unique_src["count"] = count
    unique_src["source"] = "connection_count"

    analytics["unique_src"] = unique_src
    eve["analytics"] = analytics

    dragonfly.analyze_event(default_analyzer, eve)
end
