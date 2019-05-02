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
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-priority-test.log
    cat /dev/null > /var/log/dragonfly-mle/debug.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-mle.log
}

function teardown() {
    redis-cli shutdown
}

@test "Test Alert Triage" {
    # skip "For debug purposes only. Output depends on the analyzers included in the scores."
    # Copy Test Files Into Position
    [ -e /usr/local/dragonfly-mle/analyzer/dga-lr-mle.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/ip-geolocation.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/country-anomaly.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/ip-utils.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/utils.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/internal-ip.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/alert-dns-cache.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/overall-priority.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/time-anomaly.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/signature-anomaly.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/total-bytes-rank.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/write-to-log.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/router-filter.lua ]
    cp test/overall-priority/priority-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp test/overall-priority/priority-test-filter.lua /usr/local/dragonfly-mle/filter/.
    cp test/overall-priority/priority-test-data.json /usr/local/mle-data/.

    # cp ip-util/ipblocklist.txt /usr/local/dragonfly-mle/analyzer/.
    # cp ip-util/RW_IPBL.txt /usr/local/dragonfly-mle/analyzer/.
    # cp ip-util/zeus_badips.txt /usr/local/dragonfly-mle/analyzer/.
    # cp ip-util/IP2LOCATION-LITE-DB1.CSV /usr/local/dragonfly-mle/analyzer/.
    # cp ip-util/country-codes.txt /usr/local/dragonfly-mle/analyzer/.

    cd /usr/local/dragonfly-mle/analyzer
    sed -i "s/local subnet_ipv4 =.*/local subnet_ipv4 = '71.219.178.0'/g" internal-ip.lua
    cd $OLDPWD

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    ./bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"
    cd $OLDPWD

    timeout=60
    n_lines=12
    log_file="/var/log/dragonfly-mle/dragonfly-priority-test.log"

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
#   run bash -c "cat /var/log/dragonfly-mle/dragonfly-priority-test.log | grep '\"event_type\":\"alert\"' | tail -n 1 | jq -r 'if .priority.priority then .priority.priority|@text else empty end'"
#   [ "$status" -eq 0 ]
#   [ "$output" = "1.2" ]
#
#   run bash -c "cat /var/log/dragonfly-mle/dragonfly-priority-test.log | grep '\"event_type\":\"alert\"' | tail -n 1 | jq -r 'if .priority.details.dga.domain then .priority.details.dga.domain|@text else empty end'"
#   [ "$status" -eq 0 ]
#   [ "$output" = "client.dropbox-dns.com" ]

#   run bash -c "cat /var/log/dragonfly-mle/dragonfly-priority-test.log | grep '\"event_type\":\"alert\"' | tail -n 1 | jq -r 'if .priority.details.time.score then .priority.details.time.score|@text else empty end'"
#   [ "$status" -eq 0 ]
#   [ "$output" = "1" ]
} 
