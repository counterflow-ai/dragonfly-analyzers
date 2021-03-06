-- ----------------------------------------------
-- Copyright (c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- IP Geolocation uses GeoIP data from IP2Location.com to indicate country based on IP

require 'analyzer/utils'
require 'analyzer/ip-utils'

local analyzer_name = 'IP Geolocation'

function setup()
    conn = hiredis.connect()
    if conn:command('PING') ~= hiredis.status.PONG then
        dragonfly.log_event(analyzer_name..': Could not connect to redis')
        dragonfly.log_event(analyzer_name..': exiting')
        os.exit()
    end

    starttime = 0 --mle.epoch()
    dragonfly.log_event(">>>>>>>> IP Geolocation")
    print(">>>>>>>> IP Geolocation Setup")
    redis_key = "ipv4_geolocation"
    local start = os.clock()

    -- Read local file, add online get later
    -- https://download.ip2location.com/lite/IP2LOCATION-LITE-DB1.CSV.ZIP
    local filepath = "analyzer/IP2LOCATION-LITE-DB1.CSV"
    local file, err = io.open(filepath,'rb')
    if file then
        line_num = 1
        while true do
            line = file:read()
            -- print(line)
            if line == nil then
                break
            elseif line ~='' then
                local min,max,code,name = line:match("\"(%d+)\",\"(%d+)\",\"(.+)\",\"(.+)\".+")
                local cmd = 'ZADD '..redis_key..' '..max..' '..name..':'..code..':'..line_num
                --local reply = conn:command_line(cmd)
                local reply = conn:command("ZADD", redis_key, max, name .. ":" .. code .. ":" .. line_num)
                if type(reply) == 'table' and reply.name ~= 'OK' then
                    dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
                end 
            end
            line_num = line_num + 1
        end
        file:close()
    end
    local now = os.clock()
    local delta = now - start
    print('Loaded '..analyzer_name..' files in '..delta..' seconds')
    dragonfly.log_event('Loaded '..analyzer_name..' files in '..delta..' seconds')
end

function loop(msg)
    local start = os.clock()
    local eve = msg
	local fields = {"ip_info.internal_ips",
                    ["ip_info.internal_ip_code"] = {ip_internal_code.SRC,
                                                    ip_internal_code.DEST},
                    ["event_type"] = {"alert",'flow'},}
    if not check_fields(eve, fields) then
        dragonfly.log_event(analyzer_name..': Required fields missing')
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end

    analytics = eve.analytics
    if not analytics then
        analytics = {}
    end
    ip_geo = {}

    local internal_ips = eve.ip_info.internal_ips
    local internal_ip_code = eve.ip_info.internal_ip_code
    local external_ip = get_external_ip(eve.src_ip, eve.dest_ip, internal_ip_code)
    if external_ip == nil then
        location = {}
        location["country_code"] = "US"
        location["country"] = "United States"
        ip_geo["location"] = location

        analytics["ip_geo"] = ip_geo
        eve["analytics"] = analytics
        dragonfly.analyze_event(default_analyzer, eve) 
        return
    end
    
    local ip_geo = {}
    if GetIPType(external_ip) ~= ip_version.IPV4 then  --Get IP Type of External IP
        dragonfly.log_event(analyzer_name..': not ipv4')
        dragonfly.analyze_event(default_analyzer, eve) 
        return
    end


    local ip_long = IPv4ToLong(external_ip)
    -- Get the next highest max range
    local cmd = 'ZRANGEBYSCORE '..redis_key..' '..ip_long..' +inf LIMIT 0 1'
    local reply = conn:command_line(cmd)
    for _,v in ipairs(reply) do
        if type(v) == 'table' and v.name ~= 'OK' then
            dragonfly.log_event(analyzer_name..': '..cmd..' : '..v.name)
            dragonfly.analyze_event(default_analyzer, msg) 
            return
        end 
    end
    name, code = reply[1]:match("(.+):(.+):.+") -- ignore trailing id 
    location = {}
    location["country_code"] = code
    location["country"] = name
    ip_geo["location"] = location

    analytics["ip_geo"] = ip_geo
    eve["analytics"] = analytics
    dragonfly.analyze_event(default_analyzer, eve) 
    local now = os.clock()
    local delta = now - start
    dragonfly.log_event(analyzer_name..': time: '..delta)
end
