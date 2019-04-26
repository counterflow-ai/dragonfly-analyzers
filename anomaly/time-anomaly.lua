-- ----------------------------------------------
-- Copyright(c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------


-- Time Anomaly computes an anomaly score based on time of day. Events are binned by hour. 

require 'string'
require 'analyzer/utils'
local analyzer_name = 'Time Anomaly'

function setup()
    conn = hiredis.connect()
    if conn:command('PING') ~= hiredis.status.PONG then
        dragonfly.log_event(analyzer_name..': Could not connect to redis')
        dragonfly.log_event(analyzer_name..': exiting')
        os.exit()
    end
    starttime = 0 --mle.epoch()
    dragonfly.log_event(analyzer_name..' setup')
    redis_key = "time-of-day"
    local cmd = 'HMSET ' .. redis_key .. ' total 0 00 0 01 0 02 0 03 0 04 0 05 0 06 0 07 0 08 0 09 0 10 0 11 0 12 0 13 0 14 0 15 0 16 0 17 0 18 0 19 0 20 0 21 0 22 0 23 0'
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
    end 
end


function loop(msg)
    local start = os.clock()
    local eve = msg
	local fields = {'timestamp'}
    if not check_fields(eve, fields) then
        dragonfly.log_event(analyzer_name..': Required fields missing')
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end
    -- "2019-01-28T17:16:12.000386-0500"
    hour = string.sub(eve.timestamp, 12, 13)
    tzone = string.sub(eve.timestamp,-5, -1)

    local cmd = 'HMGET '..redis_key..' total '..hour
    local reply = conn:command_line(cmd)
    for _,v in ipairs(reply) do
        if type(v) == 'table' and v.name ~= 'OK' then
            dragonfly.log_event(analyzer_name..': '..cmd..' : '..v.name)
            dragonfly.analyze_event(default_analyzer, msg)
            return
        elseif not tonumber(v) then
            dragonfly.log_event(analyzer_name..': Could not convert to number: '..v)
            dragonfly.analyze_event(default_analyzer, msg)
            return
        end
    end

    local total = reply[1]
    local count = reply[2]

    local prob = tonumber(count) * 1.0 / (tonumber(total) + 1)
    local inv_prob = 1 - prob

    local new_total = tonumber(total) + 1
    local new_count = tonumber(count) + 1

    local cmd = 'HMSET '..redis_key..' total '.. new_total..' '..hour..' '..new_count
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
    end 

    analytics = eve.analytics
    if not analytics then
        analytics = {}
    end
    
    timeInfo = {}
    timeInfo["hour"] = hour
    timeInfo["score"] = inv_prob
    timeInfo["count"] = count
    timeInfo["total"] = total
    timeInfo["timezone"] = tzone
    timeInfo["threshold"] = 0.9583
    analytics["time"] = timeInfo
    eve["analytics"] = analytics
    dragonfly.analyze_event(default_analyzer, eve) 
    local now = os.clock()
    local delta = now - start
    dragonfly.log_event(analyzer_name..': time: '..delta)
end
