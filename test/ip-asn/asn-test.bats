#!/usr/bin/env bats

function setup() {
    redis-server --daemonize yes 3>&- &
    redis-cli flushall 3>&- &
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-asn-test.log
    cat /dev/null > /var/log/dragonfly-mle/dragonfly-mle.log
}

function teardown() {
    redis-cli shutdown
}

@test "Test IP ASN Lookup" {
    # Copy Test Files Into Position
    cp ip-util/ip2asn-v4-u32.tsv /usr/local/dragonfly-mle/analyzer/.
    cp ip-util/ip-utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp util/utils.lua /usr/local/dragonfly-mle/analyzer/.
    cp ip-util/ip-asn.lua /usr/local/dragonfly-mle/analyzer/.
    cp util/write-to-log.lua /usr/local/dragonfly-mle/analyzer/.
    cp test/ip-asn/asn-test-config.lua /usr/local/dragonfly-mle/config/config.lua
    cp test/ip-asn/asn-test-filter.lua /usr/local/dragonfly-mle/filter/.
    cp ip-util/internal-ip.lua /usr/local/dragonfly-mle/analyzer/.
    cp test/ip-asn/asn-test-data.json /usr/local/mle-data/.

    # Fire Up Dragonfly
    cd /usr/local/dragonfly-mle
    ./bin/dragonfly-mle 3>&- &
    dragonfly_pid=$!
    echo "# $dragonfly_pid"
    cd $OLDPWD

    timeout=600
    n_lines=3
    log_file="/var/log/dragonfly-mle/dragonfly-asn-test.log"

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
    tail_command="tail -n ${n_lines} ${log_file}"
    jq_command=$( ./test/generate_jq_command.py "analytics.ip_asn.country_code" "analytics.ip_asn.number" "analytics.ip_asn.name" )
    command="${tail_command} | ${jq_command}"
    expected_output=$(cat <<EOF
"AU,56203,GTELECOM-AUSTRALIAGtelecom-AUSTRALIA"
"CN,4134,CHINANET-BACKBONENo.31,Jin-rongStreet"
"US,13335,CLOUDFLARENET-Cloudflare,Inc."

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
