#!/usr/bin/sh
redis-server --daemonize yes --loadmodule /usr/local/lib/redis-ml.so
redis-cli flushall
lua test/redis/redis-test.lua
redis-cli shutdown
