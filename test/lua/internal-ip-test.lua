-- ----------------------------------------------
-- Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
-- Author: Collins Huff <ch@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

require 'analyzer/ip-utils'
require 'analyzer/internal-ip'

function test_bitand_nums()
    local x = 123
    local y = 123
    local z = 123
    assert(bitand(x,y) == z)

    x = 123
    y = 456
    z = 72
    assert(bitand(x,y) == z)

    x = nil
    y = 456
    z = 72
    assert(bitand(x,y) == nil)
end

function test_bitand_strs()
    local x = "1111"
    local y = "1111"
    local z = "1111"
    assert(bitand(x,y) == z)

    x = "1111"
    y = "0000"
    z = "0000"
    assert(bitand(x,y) == z)

    x = "0000"
    y = "0000"
    z = "0000"
    assert(bitand(x,y) == z)

    x = "1010"
    y = "1101"
    z = "1000"
    assert(bitand(x,y) == z)

    x = nil
    y = "1111"
    z = nil
    assert(bitand(x,y) == nil)
end

function test_get_ip_type()
    local ipv4 = "192.168.0.1"
    assert(GetIPType(ipv4) == 1)

    local ipv6 = "2001:0db8:0000:0000:0000:0000:0000:0000"
    assert(GetIPType(ipv6) == 2)

    local malformed_ipv4 = "..."
    assert(GetIPType(malformed_ipv4) == 3)

    local malformed_ipv6 = ":::::::::"
    assert(GetIPType(malformed_ipv6) == 3)
end

function test_ipv4_to_long()
    local ip = "192.168.0.1"
    ip_int = 3232235521
    assert(IPv4ToLong(ip) == ip_int)

    ip = "255.255.255.255"
    ip_int = 4294967295
    assert(IPv4ToLong(ip) == ip_int)

    ip = "1.1.1.1.1.1"
    ip_int = nil
    assert(IPv4ToLong(ip) == ip_int)

    ip = "...."
    ip_int = nil
    assert(IPv4ToLong(ip) == ip_int)
end

function test_ipv6_to_bin()
    local ipv6 = "1234:5678:9ABC:DEF0:DEAD:BEEF:0000:ABCD"
    local ipv6_bin = "00010010001101000101011001111000100110101011110011011110111100001101111010101101101111101110111100000000000000001010101111001101"
    assert(ipv6_to_bin(ipv6) == ipv6_bin)

    local ipv6 = "1234:5678:9ABC:DEF0:DEAD:BEEF:0000:ABCD"
    local ipv6_bin = "00010010001101000101011001111000100110101011110011011110111100001101111010101101101111101110111100000000000000001010101111001101"
    assert(ipv6_to_bin(ipv6) == ipv6_bin)
end

function test_ipv4_internal()
    local subnet_ip = "192.168.0.1"
    local subnet_mask = "255.255.255.0"

    local test_ip = "192.168.0.35"
    assert(is_internal_ipv4(test_ip, subnet_ip, subnet_mask))

    test_ip = "192.168.1.35"
    assert(is_internal_ipv4(test_ip, subnet_ip, subnet_mask) == false)

    test_ip = "192.198.0.1"
    assert(is_internal_ipv4(test_ip, subnet_ip, subnet_mask) == false)
end

function test_ipv6_internal()
    local subnet_ipv6 = "2001:0db8:0000:0000:0000:0000:0000:0000"
    local subnet_mask = "ffff:ffff:0000:0000:0000:0000:0000:0000"

    local test_ipv6 = "2001:0db8:0000:0000:0000:0000:0000:1111"
    assert(is_internal_ipv6(test_ipv6, subnet_ipv6, subnet_mask))

    test_ipv6 = "3001:0db8:0000:0000:0000:0000:0000:1111"
    assert(is_internal_ipv6(test_ipv6, subnet_ipv6, subnet_mask) == false)
end


test_bitand_nums()
test_bitand_strs()
test_get_ip_type()
test_ipv4_to_long()
test_ipv6_to_bin()
test_ipv4_internal()
test_ipv6_internal()
print("PASS")
