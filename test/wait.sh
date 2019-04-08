#!/bin/sh
# expects 1st arg to be log file, 2nd arg number of lines, 3rd arg timeout in sec
# waits until the log file has the expected number of lines or timeout has elapsed
start=$(date +%s)
n=$( wc -l < $1 )
while [ $n -lt $2 ] 
do 
    n=$( wc -l < $1 )
    sleep 1
    now=$(date +%s)
    duration=$(( now - start ))
    if [ $duration -gt $3 ] 
    then
        exit 1
    fi
done
