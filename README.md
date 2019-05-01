# Dragonfly Analyzers

These are a collection of analyzers to use with the [Dragonfly Machine Learning Engine (MLE)](https://github.com/counterflow-ai/dragonfly-mle)on [OPNids](https://opnids.io). An analyzer processes an input event, updating the event with additional information or caching data from the event in Redis for future use. 

## Included Analyzers

| Filename | Description |
| ----- | ----- |
| anomaly/country-anomaly.lua | Flag rare countries |
| anomaly/signature-anomaly.lua  | Flag rare alerts |
| anomaly/time-anomaly.lua  | Flag events at odd hours |
| blacklist/example-dns.lua  | Use abuse.ch blacklists for dns |
| blacklist/example-flow.lua  |  Use abuse.ch blacklists for dns |
| blacklist/example-tls.lua  | Check certificate validity |
| event-triage/alert-dns-cache.lua  | Copy data fields from DNS responses to following alerts |
| event-triage/alert-triage.lua | Prioritize alerts based on frequency of alerts |
| event-triage/invalid-cert-count.lua | Count invalid certificate accesses by each IP address |
| event-triage/overall-priority.lua | Combine anomaly scores into a single priority score |
| filter/default-filter.lua | Simple passthrough filter |
| filter/dga-filter.lua | Route DNS message through the DGA detector |
| ip-util/internal-ip.lua | Identify source and destination IPs as internal or external (requires config) |
| ip-util/ip-asn.lua | Annotate events with ASN |
| ip-util/ip-blacklist.lua | Annotate events based on abuse.ch blacklists |
| ip-util/ip-geolocation.lua | Use IP2location to identify which country is the source of traffic |
| machine-learning/dga-lr-mle.lua | Detect potential DGA domains with a logistic regression classifier | 
| machine-learning/dga-rf-mle.lua | Detect potential DGA domains with a random forest classifier |
| stats/flow-size-outlier.lua | Computes flow outliers using Median Absolute Deviation |
| top-talkers/connection-count-hll.lua | Track connection count by IP using a HyperLogLog sketch (probabilistic data structure) |
| top-talkers/total-bytes-rank.lua | Sum bytes across flows using Redis sorted set |
| util/router-filter.lua | Example analyzer for routing events based on a conditional test |
| util/write-to-log.ua | Convenience function to support config only routing of messages |

### Additional Utility Functions

| Filename | Description |
| ----- | ----- |
| ip-util/ip-utils.lua | Utility functions for identifying IPv4 and IPv6 addresses and more |
| util/utils.lua | Handy functions for check existence of JSON fields |

## Usage

Analyzers must be installed in the root directory of the MLE. For most installations this is `/usr/local/dragonfly-mle/analyzer`. Analyzer usage is specified in the `/usr/local/dragonfly-mle/config.lua` file.

For convenience, we have included a script to install the analyzers and filters included in this repo.


### Step 1: Connect to the OPNids CLI

```
 ssh root@192.168.0.1
 Password for root@OPNids.localdomain: 
 Last login: Fri Apr 12 19:20:41 2019 from 192.168.0.0
----------------------------------------------
       Hello, this is OPNids 18.9    
|                                            |
| Website:	https://opnids.io/           |
| Handbook:	https://docs.opnids.io/      |
| Forums:	https://discourse.opnids.io/ |
| Code:		https://github.com/opnids    |
----------------------------------------------

  1) Logout                              7) Ping host
  2) Assign interfaces                   8) Shell
  3) Set interface IP address            9) pfTop
  4) Reset the root password            10) Firewall log
  5) Reset to factory defaults          11) Reload all services
  6) Power off system                   12) Update from console
  7) Reboot system                      13) Restore a backup

 Enter an option: 8
```

### Step 2: Clone the dragonfly-analyzers repo

```
cd /usr/local
git clone https://github.com/counterflow-ai/dragonfly-analyzers.git
```

### Step 3:  Update your local IP Range

The file `dragonfly-analyzers/ip-util/internal-ip.lua` is used to identify internal IP addresses. These need to be set properly to work.
Edit the `home_net_ipv4` variable on line 31 and the `home_net_ipv6` variable on line 42 with the appropriate values.

### Step 4: Install the analyzers

To install all of the analyzers, use the included script.

```
cd dragonfly-analyzers
./install.sh --all
```
or you can install by category instead. For example:
```
cd dragonfly-analyzers
./install.sh machine-learning
```
Full usage of the install script can be seen with either `-h` or `--help`
```
# ./install.sh -h
Usage: ./install.sh
   -h|--help - Show this message
   -d|--data - Download data files
   -n|--nodata - Skip data download
   -f|--filter - Copy filter files
   -a|--all - Equivalent to ./install.sh -d -f anomaly event-triage ip-util machine-learning stats top-talkers util
Note: Configuration files must be copied manually.
```

### Step 5 (OPTIONAL): Install filters

If you installed selected analyzers only, you will want to also install the filters. These are included in the `all` group by default.
```
cd dragonfly-analyzers
./install.sh -f
```

### Step 6: Create config.lua

The `config.lua` file determines the analyzers applied to each event type and the order in which they are applied. There are example config files located in the test directories.  We have included example configurations to add a priority score to IDS alerts and run a DGA detector. They are included in the `dragonfly-analyzers/config` directory. For example, to use the priority score configuration, run the following commands: 
```
cd dragonfly-analyzers
cp config/event-triage-config.lua /usr/local/dragonfly-mle/config/config.lua
```
Note that the configuration file must be named `config.lua` or the MLE will not recognize it.

### Step 7: Restart the Dragonfly MLE

Once the config files are successfully installed, restarting the MLE is necessary. For use with OPNids:
```
configctl dragonflymle restart
```
for standalone usage:
```
cd /usr/local/dragonfly-mle
./bin/dragonfly-mle
```
If you are using OPNids, the MLE can also be restarted from the GUI. (https://docs.opnids.io/manual/gui.html)

### Step 8: Check the Output of the MLE

To check the output of the MLE, look at the `eve-mle.json` file.

```
wc -l /var/log/dragonfly-mle/eve-mle.log
tail /var/log/dragonfly-mle/eve-mle.log
```

The line count should be increasing.

If you ran these instructions as they are written you can send data to the MLE using the following command:

```
cat /path/to/dragonfly-analyzers/test/overall-priority/priority-test-data.json >> /var/log/suricata/eve.json
```

This will inject several JSON events for processing by the MLE.  Output can be checked using the same commands as listed above.


## Analyzer Description File Does Not Exist

You may see lines like the following in the MLE output:
```
dragonfly: analyzer description file /www/time.json does not exist.
```
If this occurs, the MLE is still processing events.  The description files are a way to provide an explanation of the model. The description files must be named the same as the `tag` field in the `config/config.lua` that is used by the MLE.  You can either rename the description files to match your `config.lua` or change the tags in the `config.lua` to match the description files.

## Dockerfile

The included Dockerfile loads the MLE and automatically runs the tests of these analyzers.  The test directory contains many examples of configurations using analyzers to process network metadata events. The tests can also be run from an installed version of the MLE, if desired.

