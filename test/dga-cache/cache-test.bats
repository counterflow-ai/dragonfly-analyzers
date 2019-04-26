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
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-cache-test.log
    cat /dev/null > /var/log/dragonfly-mle/debug.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-mle.log
}

# function teardown() {
#     redis-cli shutdown
# }

@test "Test DGA Cache" {
    skip "Due to the DNS and Alerts being handled by the MLE in different queues and the small test set, this test can fail intermittendly if the alerts win the race. In production the alerts come after the dns request making a race possible but unlikely"
    # Copy Test Files Into Position
    cp machine-learning/dga-lr-mle.lua /usr/local/dragonfly-mle/analyzer/.
    cp event-triage/alert-dns-cache.lua /usr/local/dragonfly-mle/analyzer/.
    cp util/write-to-log.lua /usr/local/dragonfly-mle/analyzer/.
    cp test/dga-cache/cache-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp test/dga-cache/cache-test-filter.lua /usr/local/dragonfly-mle/filter/.
    cp test/dga-cache/cache-test-data.json /usr/local/mle-data/.

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    ./bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"

    sleep 5  

    #Shutdown Dragonfly
    run pkill -P $dragonfly_pid
    [ "$status" -eq 0 ]
    run kill -9 $dragonfly_pid
    [ "$status" -eq 0 ]

    # Validate Output
    run bash -c "cat /var/log/dragonfly-mle/dragonfly-cache-test.log | grep '\"event_type\":\"alert\"' | tail -n 1 | jq -r 'if .analytics.dga then .analytics.dga|@text else empty end'"
    [ "$status" -eq 0 ]
    [ "$output" = "{\"domain\":\"client.dropbox-dns.com\",\"score\":0.49448459163219}" ]
} 
