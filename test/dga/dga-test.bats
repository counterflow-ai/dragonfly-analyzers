#!/usr/bin/env bats

function setup() {
    redis-server --loadmodule /usr/local/lib/redis-ml.so --daemonize yes 3>&- &
    redis-cli flushall 3>&- &
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-dga-test.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-mle.log
}

function teardown() {
    redis-cli shutdown
}

@test "Test DGA Example" {
    # Copy Test Files Into Position
    cp ip-util/ip-utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp util/utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp util/write-to-log.lua /usr/local/dragonfly-mle/analyzer/.
    cp machine-learning/dga-lr-mle.lua /usr/local/dragonfly-mle/analyzer/.
    cp event-triage/alert-dns-cache.lua /usr/local/dragonfly-mle/analyzer/.
    cp machine-learning/feature.lua /usr/local/dragonfly-mle/analyzer/.

    cp test/dga/dga-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp ip-util/internal-ip.lua /usr/local/dragonfly-mle/filter/.
    cp test/dga/dga-test-data.json /usr/local/mle-data/.

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    ./bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"
    cd $OLDPWD

    timeout=10
    n_lines=6
    log_file="/var/log/dragonfly-mle/dragonfly-dga-test.log"

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
    event_type="dns"
    field="analytics.dga.source"
    tail_command="tail -n '$n_lines' ${log_file}"
    jq_command1="jq -r 'select(.event_type == \"${event_type}\")'"
    jq_command2="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command1} | ${jq_command2}"
    expected_output=$(cat <<EOF
dga/dga-lr-mle.lua
dga/dga-lr-mle.lua
dga/dga-lr-mle.lua
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
    event_type="alert"
    field="analytics.dga.score"
    tail_command="tail -n '$n_lines' ${log_file}"
    jq_command1="jq -r 'select(.event_type == \"${event_type}\")'"
    jq_command2="jq -r 'if .${field} then .${field}|@text else empty end'"
    command="${tail_command} | ${jq_command1} | ${jq_command2}"
    
    run bash -c "${command}"
    echo "status = ${status}"
    scores=(${output//$'\n'/ })
    dga_score=${scores[1]}
    edu_score=${scores[0]}
    google_score=${scores[2]}
    echo "dga_score = ${dga_score}"
    echo "edu_score = ${edu_score}"
    echo "google_score = ${google_score}"

    run bash -c "echo '${dga_score}>0' | bc"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    run bash -c "echo '${dga_score}<1' | bc"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]

    run bash -c "echo '${edu_score}>0' | bc"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    run bash -c "echo '${edu_score}<1' | bc"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]

    run bash -c "echo '${google_score}>0' | bc"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    run bash -c "echo '${google_score}<1' | bc"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]

    run bash -c "echo '${dga_score}>${edu_score}' | bc"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]

    run bash -c "echo '${dga_score}>${google_score}' | bc"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
} 

