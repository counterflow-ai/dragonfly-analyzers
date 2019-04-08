#!/usr/bin/env bats

function setup() {
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-internal-test.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-mle.log
}


@test "Test Internal Network IP Extraction Example" {
    # Copy Test Files Into Position
    cp ip-util/ip-utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp util/utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp ip-util/internal-ip.lua /usr/local/dragonfly-mle/analyzer/.
    cp util/write-to-log.lua /usr/local/dragonfly-mle/analyzer/.
    cp test/ip-internal/internal-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp test/ip-internal/internal-test-filter.lua /usr/local/dragonfly-mle/filter/.
    cp test/ip-internal/internal-test-data.json /usr/local/mle-data/.

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    ./bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"
    cd $OLDPWD

    timeout=10
    n_lines=7
    log_file="/var/log/dragonfly-mle/dragonfly-internal-test.log"

    # wait until the log file has the expected number of lines
    ./test/wait.sh $log_file $n_lines $timeout 3>&-
    wait_status=$?

    #Shutdown Dragonfly
    run pkill -P $dragonfly_pid
    [ "$status" -eq 0 ]
    run kill -9 $dragonfly_pid
    [ "$status" -eq 0 ]
    [ "$wait_status" -eq 0 ]


    # Validate Output for internal_ips field
    field="ip_info.internal_ips"
    tail_command="tail -n ${n_lines} ${log_file}"
    jq_command="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
["192.168.0.104"]
["192.168.0.199","192.168.0.1"]
["192.168.0.55"]
["fe80:0000:0000:0000:103b:e444:750c:7f19"]
["fe80:0000:0000:0000:103b:e444:750c:7f19","fe80:0000:0000:0000:103b:e444:750c:7f19"]
["fe80:0000:0000:0000:103b:e444:750c:7f19"]
["71.219.167.197"]
EOF
)
    run bash -c "$command"
    echo "status = ${status}"
    echo "expected_ouput = "
    echo "${expected_output}"
    echo "output = "
    echo "${output}"
    [ "$status" -eq 0 ]
    [ "$output" = "$expected_output" ]

    field="ip_info.internal_ip_code"
    tail_command="tail -n ${n_lines} ${log_file}"
    jq_command="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
0
2
1
0
2
1
0
EOF
)
    # Validate Output for internal_ip_code field
    run bash -c "${command}"
    echo "status = ${status}"
    echo "expected_ouput = "
    echo "${expected_output}"
    echo "output = "
    echo "${output}"
    [ "$status" -eq 0 ]
    [ "$output" = "$expected_output" ]
} 
