#!/usr/bin/env bats

################################################
## Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
## Author: Andrew Fast <af@counterflowai.com>
##
## Use of this source code is governed by a BSD-style
## license that can be found in the LICENSE.txt file.
##################################################

function setup() {
    redis-server --daemonize yes 3>&- &
    redis-cli flushall 3>&- &
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-time-test.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-mle.log
}

function teardown() {
    redis-cli shutdown
}

@test "Test Time Anomaly" {
    # Copy Test Files Into Position
    cp anomaly/time-anomaly.lua /usr/local/dragonfly-mle/analyzer/.
    cp util/write-to-log.lua /usr/local/dragonfly-mle/analyzer/.
    cp test/time-anomaly/time-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp test/time-anomaly/time-test-filter.lua /usr/local/dragonfly-mle/filter/.
    cp test/time-anomaly/time-test-data.json /usr/local/mle-data/.

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    /usr/local/dragonfly-mle/bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"
    cd $OLDPWD

    timeout=10
    n_lines=100
    log_file="/var/log/dragonfly-mle/dragonfly-time-test.log"

    # wait until the log file has the expected number of lines
    ./test/wait.sh $log_file $n_lines $timeout 3>&-
    wait_status=$?

    #Shutdown Dragonfly
    run pkill -P $dragonfly_pid
    [ "$status" -eq 0 ]
    run kill -9 $dragonfly_pid
    [ "$status" -eq 0 ]
    [ "$wait_status" -eq 0 ]

    n_lines=1
    jq_command=$( ./test/generate_jq_command.py "analytics.time.threshold" "analytics.time.total" "analytics.time.timezone" "analytics.time.hour" "analytics.time.count" "analytics.time.score" )
    tail_command="tail -n ${n_lines} ${log_file}"
    
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
"0.9583,99,-0500,17,15,0.85"
EOF
)
    run bash -c "$command"
    echo "status = ${status}"
    echo "${field}"
    echo "expected_ouput = "
    echo "${expected_output}"
    echo "output = "
    echo "${output}"
    [ "$status" -eq 0 ]
    [ "$output" = "$expected_output" ]
} 
