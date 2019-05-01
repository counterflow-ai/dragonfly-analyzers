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
#analyzer_dirs="ip-util util"
analyzer_dirs=""
DATA=0
FILTER=0
DIR=""
usage=$'Usage: ./install.sh\n   -h|--help - Show this message\n   -d|--data - Download data files\n   -n|--nodata - Skip data download\n   -f|--filter - Copy filter files\n   -a|--all - Equivalent to ./install.sh -d -f anomaly event-triage ip-util machine-learning stats top-talkers util\nNote: Configuration files must be copied manually.'

if [[ $# -eq 0 ]]; then
    echo "$usage"
    exit 
fi

# As long as there is at least one more argument, keep looping
while [[ $# -gt 0 ]]; do
    key="$1"
    case "$key" in
    # Download data
        -h|--help)
        echo "$usage"
        exit
        ;;
        # Download data
        -d|--data)
        DATA=1
        ;;
        # Do NOT Download data
        -n|--nodata)
        DATA=0
        ;;
         # Download data
        -f|--filter)
        FILTER=1
        ;;
        # Install all analyzers and data
        -a|--all)
        DATA=1
        FILTER=1
        DIR=all
        ;;
        # Ignore other options
        -*)
        echo "Unknown option '$key'"
        exit
        # Grab all directories on the end
        ;;
        *) 
        DIR=$1
        # Check for directory existence
        if [ ! -d $DIR ] &&  [ ! $DIR = "all" ]; then 
            echo "No such directory $DIR"
            exit
        fi
        ;;
    esac
    analyzer_dirs="$analyzer_dirs $DIR"
    shift
done

if [[ $DATA = 1 ]] ; then
    ## For required data files in the ip-util directory
    echo "Downloading helper data sets"

    cwd=$(pwd)
    cd /usr/local/dragonfly-mle/analyzer

    # For ip-asn.lua
    wget https://iptoasn.com/data/ip2asn-v4-u32.tsv.gz
    gunzip ip2asn-v4-u32.tsv.gz

    # For ip-geolocation.lua
    wget https://download.ip2location.com/lite/IP2LOCATION-LITE-DB1.CSV.ZIP
    unzip IP2LOCATION-LITE-DB1.CSV.ZIP
    rm IP2LOCATION-LITE-DB1.CSV.ZIP

    # For ip-blacklist.lua
    wget https://feodotracker.abuse.ch/downloads/ipblocklist.txt
    wget https://ransomwaretracker.abuse.ch/downloads/RW_IPBL.txt
    wget https://zeustracker.abuse.ch/blocklist.php?download=badips -O zeus_badips.txt

    cd $cwd
fi

if [[ $FILTER = 1 ]] ; then 
    echo "install -b --suffix=.old -v filter/* $dragonfly_root/filter"
    install -b --suffix=.old -v filter/* $dragonfly_root/filter
fi 

if [[ ${#analyzer_dirs} > 1 ]] ; then

    # Set up dirs for copying
    if [[ $analyzer_dirs == *"all"* ]] ; then
        analyzer_dirs="anomaly event-triage ip-util machine-learning stats top-talkers util"
    fi

    if [[ $analyzer_dirs != *"util"* ]] ; then
        analyzer_dirs="$analyzer_dirs ip-util util"
    fi

    install_dirs=""
    for val in $analyzer_dirs; do 
        install_dirs="$install_dirs $val/*"
    done

    # Perform the install, using "backup" and "verbose" options. The script will backup
    # any files that have been updated in the analyzer directory using a `.old` suffix.
    # Note: You must copy all config files manually
    echo "install -b --suffix=.old -v $install_dirs $dragonfly_root/$destination"
    install -b --suffix=.old -v $install_dirs $dragonfly_root/$destination
fi 

# echo "$analyzer_dirs"
