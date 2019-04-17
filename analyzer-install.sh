#! /bin/bash

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

## If you prefer to use rsync, which is not installed by default on OPNids
# echo "rsync -vvu $rsync_dirs $dragonfly_root/$destination"
# rsync -vvu $rsync_dirs $dragonfly_root/$destination

# Perform the copy, using "no-clobber" and "verbose" options. The script won't copy over
# any files that have been updated in the analyzer directory
# Note: You must copy all config files manually
echo "cp -nv $rsync_dirs $dragonfly_root/$destination"
cp -nv $rsync_dirs $dragonfly_root/$destination