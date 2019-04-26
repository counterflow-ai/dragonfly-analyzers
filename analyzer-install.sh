#! /bin/bash

################################################
## Copyright (c) 2019, CounterFlow AI, Inc. All Rights Reserved.
## Author: Andrew Fast <af@counterflowai.com>
##
## Use of this source code is governed by a BSD-style
## license that can be found in the LICENSE.txt file.
##################################################

dragonfly_root="/usr/local/dragonfly-mle"
destination="analyzer"
analyzer_dirs="ip-util util"
dir=$1

# Check for directory existence
if [ ! -d $dir ] &&  [ ! $dir = "all" ]; then 
    echo "No such directory $dir"
    exit
fi

# Set up dirs for copying
analyzer_dirs="$analyzer_dirs $dir"
if [ $dir = "all" ]; then
    analyzer_dirs="anomaly event-triage ip-util machine-learning stats top-talkers util filter"
elif [ $dir = "filter" ]; then
    analyzer_dirs="filter"
    destination="filter"
elif [ $dir = "util" ]; then
    analyzer_dirs="util"
elif [ $dir = "ip-util" ]; then
    analyzer_dirs="ip-util util"
fi

rsync_dirs=""
for val in $analyzer_dirs; do 
    rsync_dirs="$rsync_dirs $val/*"
done

# Perform the install, using "backup" and "verbose" options. The script will backup
# any files that have been updated in the analyzer directory using a `.old` suffix.
# Note: You must copy all config files manually
echo "install -b --suffix=.old -v $rsync_dirs $dragonfly_root/$destination"
install -b --suffix=.old -v $rsync_dirs $dragonfly_root/$destination