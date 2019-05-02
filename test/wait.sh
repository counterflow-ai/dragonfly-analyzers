#!/bin/sh

################################################
## Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
## Author: Collins Huff <ch@counterflowai.com>
##
## Use of this source code is governed by a BSD-style
## license that can be found in the LICENSE.txt file.
##################################################

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
