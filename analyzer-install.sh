#! /bin/bash

dragonfly_root="/usr/local/dragonfly-mle"
destination="analyzer"
analyzer_dirs="ip-util util"
dir=$1

if [ ! -d $dir ] &&  [ ! $dir = "all" ]; then 
    echo "No such directory $dir"
    exit
fi

analyzer_dirs="$analyzer_dirs $dir"

if [ $dir = "all" ]; then
    analyzer_dirs="anomaly event-triage ip-util machine-learning stats top-talkers util"
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

echo "rsync -vvu $rsync_dirs $dragonfly_root/$destination"
rsync -vvu $rsync_dirs $dragonfly_root/$destination