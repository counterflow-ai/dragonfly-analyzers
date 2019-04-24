# Dragonfly Analyzers

These are a collection of analyzers to use with the [Dragonfly Machine Learning Engine (MLE)](https://github.com/counterflow-ai/dragonfly-mle)on [OPNids](https://opnids.io). An analyzer processes an input event, updating the event with additional information or caching data from the event in Redis for future use. 

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
sh analyzer-install.sh all
```
or you can install by category instead. For example:
```
cd dragonfly-analyzers
sh analyzer-install.sh machine-learning
```

### Step 5 (OPTIONAL): Install filters

If you installed selected analyzers only, you will want to also install the filters. These are included in the `all` group.
```
cd dragonfly-analyzers
sh analyzer-install.sh filter
```

### Step 6: Create config.lua

The `config.lua` file determines the analyzers applied to each event type and the order in which they are applied. There are example config files located in the test directories.  We have included example configurations to add a priority score to IDS alerts and run a DGA detector. They are included in the `dragonfly-analyzers/config` directory. For example, to use the priority score configuration, run the following commands: 
```
cd dragonfly-analyzers
cp event-triage-config.lua /usr/local/dragonfly-mle/config/config.lua
```
Note that the configuration file must be named `config.lua` or the MLE will not pick it up.

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

## Dockerfile

The included Dockerfile loads the MLE and automatically runs the tests of these analyzers.  The test directory contains many examples of using analyzers to process network metadata events.

