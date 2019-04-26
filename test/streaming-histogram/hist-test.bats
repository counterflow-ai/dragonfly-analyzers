#!/usr/bin/env bats

################################################
## Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
## Author: Andrew Fast <af@counterflowai.com>
##
## Use of this source code is governed by a BSD-style
## license that can be found in the LICENSE.txt file.
##################################################

function setup() {
    redis-server --daemonize yes --loadmodule /usr/local/lib/redis-ml.so 3>&- &
    redis-cli flushall 3>&- &
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-hist-test.log
    cat /dev/null > /var/log/dragonfly-mle/debug.log
}

function teardown() {
    redis-cli shutdown
}

@test "Test Streaming Histogram" {
    # Copy Test Files Into Position
    cp stats/streaming-histogram.lua /usr/local/dragonfly-mle/analyzer/.
    cp test/streaming-histogram/hist-test-analyzer.lua /usr/local/dragonfly-mle/analyzer/.
    cp test/streaming-histogram/hist-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp test/streaming-histogram/hist-test-filter.lua /usr/local/dragonfly-mle/filter/.
    cp test/streaming-histogram/hist-test-data.json /usr/local/mle-data/.

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    ./bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"
    cd $OLDPWD

    timeout=10
    n_lines=7
    log_file="/var/log/dragonfly-mle/dragonfly-hist-test.log"

    # wait until the log file has the expected number of lines
    ./test/wait.sh $log_file $n_lines $timeout 3>&-
    wait_status=$?

    #Shutdown Dragonfly
    run bash -c "pkill -P $dragonfly_pid"
    [ "$status" -eq 0 ]
    run bash -c "kill -9 $dragonfly_pid"
    [ "$status" -eq 0 ]
    [ "$wait_status" -eq 0 ]

    # Validate Output
    run bash -c "cat /var/log/dragonfly-mle/dragonfly-hist-test.log | tail -n 1"
    [ "$status" -eq 0 ]
    [ "$output" = "{\"point\":8,\"density\":\"3->1.5\",\"hist\":{\"1\":1,\"5\":2,\"8.5\":2,\"16\":1,\"13\":1}}" ]
} 
