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

local analyzer_name = 'IP Blacklist'

function setup()
    conn = hiredis.connect()
    if conn:command('PING') ~= hiredis.status.PONG then
        dragonfly.log_event(analyzer_name..': Could not connect to redis')
        dragonfly.log_event(analyzer_name..': exiting')
        os.exit()
    end
    starttime = 0 --mle.epoch()
    redis_key = "ip_blacklist"
    local start = os.clock()

    -- Feodo Blocklist - https://feodotracker.abuse.ch/downloads/ipblocklist.txt
    -- Ransomware List - https://ransomwaretracker.abuse.ch/downloads/RW_IPBL.txt
    -- Zeus List - https://zeustracker.abuse.ch/blocklist.php?download=badips
    -- http_get (file_url, filename)

    files = { feodo = "analyzer/ipblocklist.txt", ransomware = "analyzer/RW_IPBL.txt" , zeus = "analyzer/zeus_badips.txt" }

    for name, filename in pairs(files) do
        local file, err = io.open(filename, 'rb')
        if file then
            while true do
                line = file:read()
                if line == nil then
                    break
                elseif line ~='' and not line:find("^#") then
                    local cmd = 'SET '..redis_key..':'..line..' '..name
                    local reply = conn:command_line(cmd)
                    if type(reply) == 'table' and reply.name ~= 'OK' then
                        dragonfly.log_event(cmd..' : '..reply.name)
                    end 
                end
            end
            file:close()
        end
    end
    local now = os.clock()
    local delta = now - start
    print ('Loaded '..analyzer_name..' files in '..delta..' seconds')
    dragonfly.log_event('Loaded '..analyzer_name..' files in '..delta..' seconds')
end

function loop(msg)
    local start = os.clock()
    local eve = cjson.decode(msg)
	local fields = {"ip_info.internal_ips",
                    ["ip_info.internal_ip_code"] = {ip_internal_code.SRC,
                                                    ip_internal_code.DEST},
                    ["event_type"] = {"alert",'flow'},}
    if not check_fields(eve, fields) then
        dragonfly.log_event(analyzer_name..': Required fields missing')
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

    analytics = eve.analytics
    if not analytics then
        analytics = {}
    end
    
    ip_rep = {}
    ip_rep["ip_rep"] = 'NONE'
    local cmd = 'GET ip_blacklist:' .. external_ip
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
    else 
        ip_rep["ip_rep"] = reply
    end

    analytics["ip_rep"] = ip_rep
    eve["analytics"] = analytics
    dragonfly.analyze_event(default_analyzer, cjson.encode(eve)) 
    local now = os.clock()
    local delta = now - start
    dragonfly.log_event(analyzer_name..': time: '..delta)
end
