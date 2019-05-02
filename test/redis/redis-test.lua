local hiredis = require 'hiredis'
redis_host = "127.0.0.1"
redis_port = "6379"

function test_connect_to_redis()
    conn = hiredis.connect(redis_host, redis_port)
    assert(conn:command("PING") == hiredis.status.PONG)
end

function test_get_set()
    local key = 'test_key'
    local value = 10

    print()
    print('SETEX')
    conn:command("SETEX", key, "60" , value)
    reply = conn:command("GET", key)
    print(reply, type(reply))
    if type(reply) == 'table' then
        for k,v in pairs(reply) do
            print(k,v)
        end
    end

    print()
    print('GET')
    reply = conn:command("GET", 'nonexistant_key')
    print(reply, type(reply))
    if type(reply) == 'table' then
        for k,v in pairs(reply) do
            print(k,v)
        end
    end

    print()
    print('INCR')
    reply = conn:command("INCR" , key)
    print(reply, type(reply))
    if type(reply) == 'table' then
        for k,v in pairs(reply) do
            print(k,v)
        end
    end

    print()
    print('SADD')
    reply = conn:command("SADD", key, value)
    print(reply, type(reply))
    if type(reply) == 'table' then
        for k,v in pairs(reply) do
            print(k,v)
        end
    end

    print()
    print('SCARD')
    reply = conn:command("SCARD", key, value)
    print(reply, type(reply))
    if type(reply) == 'table' then
        for k,v in pairs(reply) do
            print(k,v)
        end
    end

end

function test_hget()
    local key = 'test_histogram'
    local reply = conn:command("HGETALL", key)
    print('type reply', type(reply))
    print('len reply', #reply)
    for k,v in pairs(reply) do
        print(k,v)
    end
end

function test_incr()
end

function test_hll()
    reply = conn:command("PFADD", key, external_ip) -- PFADD returns 1 if at least one internal register has altered.
    count = conn:command("PFCOUNT", key)
end

function test_hm()
    local key = 'test_key_hm'
    local field = 'field1'
    local value = 10

    print()
    print('HMSET')
    reply = conn:command("HMSET", key, 'field1', '1')
    print(reply, type(reply))
    if type(reply) == 'table' then
        for k,v in pairs(reply) do
            print(k,v)
        end
    end

    print()
    print('HMSET')
    reply = conn:command("HMSET", key, 'field2', '2')
    print(reply, type(reply))
    if type(reply) == 'table' then
        for k,v in pairs(reply) do
            print(k,v)
        end
    end

    print()
    print('HMGET')
    reply = conn:command('HMGET', key, 'field1', 'field2', 'field3')
    if type(reply) == 'table' then
        for k,v in pairs(reply) do
            print(k, v, type(v))
        end
    end

    print()
    print('HINCRBY')
    reply = conn:command("HINCRBY", key, 'field1', 1)
    print(reply, type(reply))
    if type(reply) == 'table' then
        for k,v in pairs(reply) do
            print(k,v)
        end
    end
end

function test_logreg()
    reply = conn:command("ML.LOGREG.SET","dga","-2.42064408839","1.99545844518","-1.70241301806","0.00306950873423")
    reply = conn:command("ML.LOGREG.PREDICT", "dga", unpack(features))
end

function test_sorted_set()
    conn:command("ZADD", redis_key, max, name .. ":" .. code .. ":" .. line_num)
    reply = conn:command("ZRANGEBYSCORE", redis_key, ip_long, "+inf", "LIMIT", "0", "1") 
    dest_rank = conn:command("ZRANK",  "total_bytes_rank:dest", eve.dest_ip )
    dest_size = conn:command("ZCARD", "total_bytes_rank:dest")
    dest_bytes = conn:command("ZINCRBY", hash_id ..":dest", eve.flow.bytes_toclient, eve.dest_ip)
end

test_connect_to_redis()
--test_get_set()
--test_hm()
test_hget()
