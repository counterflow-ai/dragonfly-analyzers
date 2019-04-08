#!/usr/bin/env bats

function setup() {
    redis-server --daemonize yes 3>&- &
    redis-cli flushall 3>&- &
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-reputation-test.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-mle.log
}

function teardown() {
    redis-cli shutdown
}

@test "Test IP Reputation Example" {
    # Copy Test Files Into Position
    cp analyzer/utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/ip-utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/internal-ip.lua /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/write-to-log.lua /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/ip-blacklist.lua /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/ipblocklist.txt /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/zeus_badips.txt /usr/local/dragonfly-mle/analyzer/.
    cp analyzer/RW_IPBL.txt /usr/local/dragonfly-mle/analyzer/.
    cp test/ip-reputation/reputation-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp analyzer/internal-ip.lua /usr/local/dragonfly-mle/filter/.
    cp test/ip-reputation/reputation-test-data.json /usr/local/mle-data/.

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    ./bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"
    cd $OLDPWD

    timeout=10
    n_lines=3
    log_file="/var/log/dragonfly-mle/dragonfly-reputation-test.log"

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
    field="analytics.ip_rep.ip_rep"
    tail_command="tail -n ${n_lines} ${log_file}"
    jq_command="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
zeus
ransomware
feodo

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
