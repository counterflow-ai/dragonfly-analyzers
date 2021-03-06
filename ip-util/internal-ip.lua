-- ----------------------------------------------
-- Copyright (c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Collins Huff <ch@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- ----------------------------------------------
-- Analyzer to extract the internal ip address from the src_ip
-- and dest_ip fields (ipv4 and ipv6)
-- ----------------------------------------------

require 'analyzer/utils'
require 'analyzer/ip-utils'

local home_net_ipv4 = {
                     ['192.168.0.0'] = '255.255.0.0',
                     ['10.0.0.0'] = '255.0.0.0',
                     ['172.16.0.0'] = '255.255.255.0',
                     ['71.219.178.0'] = '255.255.255.0', -- Needed for overall priority test
                     ['71.219.167.0'] = '255.255.255.0', -- Needed for overall priority test
                     }

local home_net_ipv6 = {
                     ['fe80:0000:0000:0000:f690:eaff:fe10:2f62'] = 'ffff:ffff:ffff:ffff:0000:0000:0000:0000',
                     ['fe80:0000:0000:0000:da08:e7e3:9a3c:7199'] = 'ffff:ffff:ffff:ffff:0000:0000:0000:0000',
                     }


local analyzer_name = 'Internal IP'

function setup()
    print('>>>>>>>> Internal IP Running')
    dragonfly.log_event('>>>>>>>> Internal IP Running')

    print('Internal IP IPv4 Home net settings')
    dragonfly.log_event('Internal IP IPv4 Home net settings')
    for ip, mask in pairs(home_net_ipv4) do 
        print('IP:   '..ip)
        print('Mask: '..mask)
        dragonfly.log_event('IP:   '..ip)
        dragonfly.log_event('Mask: '..mask)
    end

    print('Internal IP IPv6 Home net settings')
    dragonfly.log_event('Internal IP IPv6 Home net settings')
    for ip, mask in pairs(home_net_ipv6) do 
        print('IP:   '..ip)
        print('Mask: '..mask)
        dragonfly.log_event('IP:   '..ip)
        dragonfly.log_event('Mask: '..mask)
    end

end

function loop(msg)
    local start = os.clock()
    local eve = msg
	local fields = {'src_ip',
			        'dest_ip',}
    if not check_fields(eve, fields) then
        dragonfly.log_event(analyzer_name..': Required fields missing')
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end

    local ip_info = eve.ip_info
    if not ip_info then
        ip_info = {}
    end

    local internal_ips = {}

    if is_internal(eve.src_ip, home_net_ipv4, home_net_ipv6) then
        table.insert(internal_ips, eve.src_ip)
        ip_info["internal_ip_code"] = ip_internal_code.SRC
    end

    if is_internal(eve.dest_ip, home_net_ipv4, home_net_ipv6) then
        table.insert(internal_ips, eve.dest_ip)
        ip_info["internal_ip_code"] = ip_internal_code.DEST
    end

    if #internal_ips == 0 then
        ip_info["internal_ip_code"] = ip_internal_code.NONE
        dragonfly.log_event(analyzer_name..':  Both src and dest ips are external')
    end

    if #internal_ips == 2 then
        ip_info["internal_ip_code"] = ip_internal_code.BOTH
    end

    ip_info["internal_ips"] = internal_ips
    eve["ip_info"] = ip_info

    dragonfly.analyze_event(default_analyzer, eve)
    local now = os.clock()
    local delta = now - start
    dragonfly.log_event(analyzer_name..': time: '..delta)
end
