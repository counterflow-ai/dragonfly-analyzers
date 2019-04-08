#!/usr/bin/env bats

function setup() {
    redis-server --daemonize yes 3>&- &
    redis-cli flushall 3>&- &
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-country-test.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-country-test-debug.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-mle.log
}

function teardown() {
    redis-cli shutdown
}

@test "Test Country Anomaly" {
    # Copy Test Files Into Position
    cp analyzer/IP2LOCATION-LITE-DB1.CSV /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/country-codes.txt /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/ip-utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/internal-ip.lua /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/ip-geolocation.lua /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/write-to-log.lua /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/country-anomaly.lua /usr/local/dragonfly-mle/analyzer/.
    cp test/country-anomaly/country-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp test/country-anomaly/country-test-filter.lua /usr/local/dragonfly-mle/filter/.
    cp test/country-anomaly/country-test-data.json /usr/local/mle-data/.

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    ./bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"
    cd $OLDPWD

    n_lines=7
    log_file="/var/log/dragonfly-mle/dragonfly-country-test.log"
    timeout=60

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
    field="analytics.country.score"
    tail_command="tail -n ${n_lines} ${log_file}"
    jq_command="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
1
1
1
0.75
0.8
0.66666666666667
0.85714285714286
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
