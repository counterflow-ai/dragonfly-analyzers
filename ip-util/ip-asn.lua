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
-- ----------------------------------------------


require 'analyzer/utils'
require 'analyzer/ip-utils'

local analyzer_name = 'IP ASN'

function setup()
    conn = hiredis.connect()
    if conn:command('PING') ~= hiredis.status.PONG then
        dragonfly.log_event(analyzer_name..': Could not connect to redis')
        dragonfly.log_event(analyzer_name..': exiting')
        os.exit()
    end

    starttime = 0 --mle.epoch()
    dragonfly.log_event(">>>>>>>> IP ASN")
    print(">>>>>>>> IP ASN Setup")
    redis_key = "ipv4_asn"
    local start = os.clock()
    local cmd = 'EXISTS '..redis_key
    local reply = conn:command_line(cmd)

    if tonumber(reply) and tonumber(reply) == 1 then
        dragonfly.log_event(analyzer_name..': files already loaded')
        return
    end

    -- https://iptoasn.com/
    local filepath = "analyzer/ip2asn-v4-u32.tsv"
    local file, err = io.open(filepath,'rb')
    if file then
        line_num = 1
        while true do
            line = file:read()
            -- print(line)
            if line == nil then
                break
            elseif line ~='' then
                -- 16778240	16778495	56203	AU	GTELECOM-AUSTRALIA Gtelecom-AUSTRALIA
                local min,max,asn_number,country_code,asn_name = line:match('(%d+)\t(%d+)\t(%d+)\t(.+)\t(.+)')
                if min and max and asn_number and country_code and asn_name then
                    local k = asn_number..':'..country_code..':'..asn_name..':'..line_num
                    k = k:gsub("%s+", "")
                    local cmd = 'ZADD '..redis_key..' '..max..' '.. k
                    local reply = conn:command_line(cmd)
                    if type(reply) == 'table' and reply.name ~= 'OK' then
                        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
                    end 
                else
                    dragonfly.log_event(analyzer_name..': Could not match required fields: '..line)
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

    local internal_ips = eve.ip_info.internal_ips
    local internal_ip_code = eve.ip_info.internal_ip_code
    local external_ip = get_external_ip(eve.src_ip, eve.dest_ip, internal_ip_code)
    if external_ip == nil then
        dragonfly.analyze_event(default_analyzer, msg) 
        return
    end
    ip_asn = {}
    
    if GetIPType(external_ip) ~= ip_version.IPV4 then  --Get IP Type of External IP
        dragonfly.log_event(analyzer_name..': not ipv4')
        dragonfly.analyze_event(default_analyzer, msg) 
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
    local asn_number, country_code, asn_name = reply[1]:match("(.+):(.+):(.+):.+") -- ignore trailing id 
    ip_asn["country_code"] = country_code
    ip_asn["number"] = asn_number
    ip_asn["name"] = asn_name

    analytics["ip_asn"] = ip_asn
    eve["analytics"] = analytics
    dragonfly.analyze_event(default_analyzer, eve) 
    local now = os.clock()
    local delta = now - start
    dragonfly.log_event(analyzer_name..': time: '..delta)
end
