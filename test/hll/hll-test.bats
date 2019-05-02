#!/usr/bin/env bats

################################################
## Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
## Author: Andrew Fast <af@counterflowai.com>
##
## Use of this source code is governed by a BSD-style
## license that can be found in the LICENSE.txt file.
##################################################

function setup() {
    redis-server --loadmodule /usr/local/lib/redis-ml.so --daemonize yes
    redis-cli flushall 3>&- &
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-hll-test.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-mle.log
}

function teardown() {
    redis-cli shutdown
}

@test "Test HLL Example" {
    # Copy Test Files Into Position
    [ -e /usr/local/dragonfly-mle/analyzer/ip-utils.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/utils.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/write-to-log.lua ]
    [ -e /usr/local/dragonfly-mle/analyzer/connection-count-hll.lua ]

    cp test/hll/hll-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp ip-util/internal-ip.lua /usr/local/dragonfly-mle/filter/.
    cp test/hll/hll-test-data.json /usr/local/mle-data/.

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    ./bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"
    cd $OLDPWD

    timeout=10
    n_lines=5
    log_file="/var/log/dragonfly-mle/dragonfly-hll-test.log"

    # wait until the log file has the expected number of lines
    ./test/wait.sh $log_file $n_lines $timeout 3>&-
    wait_status=$?

    #Shutdown Dragonfly
    run pkill -P $dragonfly_pid
    [ "$status" -eq 0 ]
    run kill -9 $dragonfly_pid
    [ "$status" -eq 0 ]
    [ "$wait_status" -eq 0 ]

    # Validate Output
    event_type="flow"
    field="analytics.unique_src.count"
    tail_command="tail -n '$n_lines' ${log_file}"
    jq_command1="jq -r 'select(.event_type == \"${event_type}\")'"
    jq_command2="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command1} | ${jq_command2}"
    expected_output=$(cat <<EOF
1
2
3
4
5

EOF
)
    run bash -c "${command}"
    echo "status = ${status}"
    echo "expected_ouput = "
    echo "${expected_output}"
    echo "output = "
    echo "${output}"
    [ "$status" -eq 0 ]
    [ "$output" = "$expected_output" ]
} 
