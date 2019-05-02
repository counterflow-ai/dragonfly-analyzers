-- ----------------------------------------------
-- Copyright (c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- Moves DGA results from DNS event to corresponding Alerts for that IP

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
