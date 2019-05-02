-- ----------------------------------------------
-- Copyright (c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Andrew Fast <af@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------


-- Lua utilities for working with IP addresses

ip_internal_code = {SRC = 0, DEST = 1, BOTH = 2, NONE = 3}
ip_version = {ERROR = 0, IPV4 = 1, IPV6 = 2, STRING = 3}

-- ----------------------------------------------
-- Function from https://stackoverflow.com/questions/10975935/lua-function-check-if-ipv4-or-ipv6-or-string
-- Get IP Type
-- ----------------------------------------------
function GetIPType(ip)
    if type(ip) ~= "string" then return ip_version.ERROR end

    -- check for format 1.11.111.111 for ipv4
    local chunks = {ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
    if #chunks == 4 then
        for _,v in pairs(chunks) do
            if tonumber(v) > 255 then return ip_version.STRING end
        end
    return ip_version.IPV4
    end

    -- check for ipv6 format, should be 8 'chunks' of numbers/letters
    -- without leading/trailing chars
    -- or fewer than 8 chunks, but with only one `::` group
    local chunks = {ip:match("^"..(("([a-fA-F0-9]*):"):rep(8):gsub(":$","$")))}
    if #chunks == 8 or #chunks < 8 and ip:match('::') and not ip:gsub("::","",1):match('::') then
        for _,v in pairs(chunks) do
            if #v > 0 and tonumber(v, 16) > 65535 then 
                return ip_version.STRING end
        end
        return ip_version.IPV6
    end

    return ip_version.STRING
end


function IPv4ToLong(ip)
    if type(ip) ~= "string" or ip == "" then
        return nil 
    end
    local chunks = {ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
    if #chunks ~= 4 then return nil end

    o1 = chunks[1]
    o2 = chunks[2]
    o3 = chunks[3]
    o4 = chunks[4]

    local num = 2^24*o1 + 2^16*o2 + 2^8*o3 + o4
    return num
end


function readIP2Location(filepath)
    local file, err = io.open(filepath,'rb')
    if file then
        line_num = 1
        while true do
            line = file:read()
            print(line)
            if line == nil then
                break
            elseif line ~='' then
                local min,max,code,name = line:match("\"(%d+)\",\"(%d+)\",\"(.+)\",\"(.+)\".+")
                -- print(min)
                -- print(max)
                -- print(code)
                -- print(name)
                print(max .. " " .. name .. ":" .. code .. ":" .. line_num)
            end
            line_num = line_num + 1
        end
        file:close()
    end
end

-- ----------------------------------------------
-- Function from https://stackoverflow.com/questions/32387117/bitwise-and-in-lua
-- ----------------------------------------------
function bitand(a, b)
    if type(a) == "number" and type(b) == "number" then
        local result = 0
        local bitval = 1
        while a > 0 and b > 0 do
          if a % 2 == 1 and b % 2 == 1 then -- test the rightmost bits
              result = result + bitval      -- set the current bit
          end
          bitval = bitval * 2 -- shift left
          a = math.floor(a/2) -- shift right
          b = math.floor(b/2)
        end
        return result
    end
    if type(a) == "string" and type(b) == "string" then
        local result = ""
        for i = 1, #a do
            if a:sub(i,i) == "1" and b:sub(i,i) == "1" then
                result = result .. "1"
            else
                result = result .. "0"
            end
        end
        return result
    end

end

local hex_to_bin = {["0"] = "0000", ["1"] = "0001", ["2"] = "0010", ["3"] = "0011",
                    ["4"] = "0100", ["5"] = "0101", ["6"] = "0110", ["7"] = "0111",
                    ["8"] = "1000", ["9"] = "1001", ["A"] = "1010", ["B"] = "1011",
                    ["C"] = "1100", ["D"] = "1101", ["E"] = "1110", ["F"] = "1111",
                    ["a"] = "1010", ["b"] = "1011", ["c"] = "1100", ["d"] = "1101",
                    ["e"] = "1110", ["f"] = "1111"}

function ipv6_to_bin(ip)
    local result = ""
    for i = 1, #ip do
        local hex_digit = ip:sub(i,i)
        if hex_digit ~= ":" then
            result = result .. hex_to_bin[hex_digit]
        end
    end
    return result
end

function is_internal_ipv4(ip, subnet_ip, subnet_mask)
    local ip_int = IPv4ToLong(ip)
    local subnet_ip_int = IPv4ToLong(subnet_ip)
    local subnet_mask_int = IPv4ToLong(subnet_mask)
    local subnet_result = bitand(subnet_ip_int, subnet_mask_int)
    local ip_result = bitand(ip_int, subnet_mask_int)
    return (ip_result == subnet_result)
end

function is_internal_ipv6(ip, subnet_ip, subnet_mask)
    local ip_bin = ipv6_to_bin(ip)
    local subnet_ip_bin = ipv6_to_bin(subnet_ip)
    local subnet_mask_bin = ipv6_to_bin(subnet_mask)
    local subnet_result = bitand(subnet_ip_bin, subnet_mask_bin)
    local ip_result = bitand(ip_bin, subnet_mask_bin)
    return (ip_result == subnet_result)
end

function is_internal(ip, home_net_ipv4, home_net_ipv6)
    local ipv = GetIPType(ip)
    if ipv == ip_version.IPV4 then
        for home_ip, home_mask in pairs(home_net_ipv4) do
            local is_internal = is_internal_ipv4(ip, home_ip, home_mask)
            if is_internal == true then
                return true
            end
        end
    elseif ipv == ip_version.IPV6 then
        for home_ip, home_mask in pairs(home_net_ipv6) do
            local is_internal = is_internal_ipv6(ip, home_ip, home_mask)
            if is_internal == true then
                return true
            end
        end
    end
    return false
end

function get_external_ip(src_ip, dest_ip, code)
    if code == ip_internal_code.SRC then
        return dest_ip
    elseif code == ip_internal_code.DEST then
        return src_ip
    else
        return nil
    end
end
