#!/usr/bin/env bats

function setup() {
    redis-server --daemonize yes 3>&- &
    redis-cli flushall 3>&- &
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-sig-test.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-mle.log
}

function teardown() {
    redis-cli shutdown
}

@test "Test Signature Anomaly" {
    # Copy Test Files Into Position
    cp anomaly/signature-anomaly.lua /usr/local/dragonfly-mle/analyzer/.
    cp util/write-to-log.lua /usr/local/dragonfly-mle/analyzer/.
    cp test/signature-anomaly/sig-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp test/signature-anomaly/sig-test-filter.lua /usr/local/dragonfly-mle/filter/.
    cp test/signature-anomaly/sig-test-data.json /usr/local/mle-data/.

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    /usr/local/dragonfly-mle/bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"
    cd $OLDPWD

    timeout=10
    n_lines=3
    log_file="/var/log/dragonfly-mle/dragonfly-sig-test.log"

    # wait until the log file has the expected number of lines
    ./test/wait.sh $log_file $n_lines $timeout 3>&-
    wait_status=$?

    #Shutdown Dragonfly
    run pkill -P $dragonfly_pid
    [ "$status" -eq 0 ]
    run kill -9 $dragonfly_pid
    [ "$status" -eq 0 ]
    [ "$wait_status" -eq 0 ]

    field="analytics.signature.threshold"
    tail_command="tail -n ${n_lines} ${log_file}"
    jq_command="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
0
0.5
0.66666666666667
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

    field="analytics.signature.count"
    tail_command="tail -n ${n_lines} ${log_file}"
    jq_command="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
1
1
1
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

    field="analytics.signature.total"
    tail_command="tail -n ${n_lines} ${log_file}"
    jq_command="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
1
2
3
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

    field="analytics.signature.score"
    tail_command="tail -n ${n_lines} ${log_file}"
    jq_command="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
0
0.5
0.66666666666667
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

    field="analytics.signature.unique_signatures"
    tail_command="tail -n ${n_lines} ${log_file}"
    jq_command="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
1
2
3
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
