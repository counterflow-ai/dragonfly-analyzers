#!/usr/bin/env bats

function setup() {
    redis-server --daemonize yes 3>&- &
    redis-cli flushall 3>&- &
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-geo-test.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-mle.log
}

function teardown() {
    redis-cli shutdown
}

@test "Test IP Geolocation Example" {
    # Copy Test Files Into Position
    cp ip-util/IP2LOCATION-LITE-DB1.CSV /usr/local/dragonfly-mle/analyzer/.
    cp ip-util/ip-utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp util/utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp ip-util/ip-geolocation.lua /usr/local/dragonfly-mle/analyzer/.
    cp util/write-to-log.lua /usr/local/dragonfly-mle/analyzer/.
    cp test/ip-geolocation/geo-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp test/ip-geolocation/geo-test-filter.lua /usr/local/dragonfly-mle/filter/.
    cp ip-util/internal-ip.lua /usr/local/dragonfly-mle/analyzer/.
    cp test/ip-geolocation/geo-test-data.json /usr/local/mle-data/.

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    ./bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"
    cd $OLDPWD

    timeout=60
    n_lines=5
    log_file="/var/log/dragonfly-mle/dragonfly-geo-test.log"

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
    field="analytics.ip_geo.location.country_code"
    tail_command="tail -n ${n_lines} ${log_file}"
    jq_command="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
CH
US
PL
US

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

    # Validate Output
    field="analytics.ip_geo.location.country"
    jq_command="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
Switzerland
United States
Poland
United States

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
