# Model Explainability

The Dragonfly MLE contains an API to provide a model explanation. The explanation files are included in this `www` folder. The names of the files *must* match the _tags_ in the config.lua file.  If you see an error such as `dragonfly: analyzer description file /www/dns.json does not exist.`, this means there is no file in the `www` directory matching the that tag name.  We have included desriptors for each of the analyzers in this repo, but the file names will need to vary based on the specific configuration being run. 

## Tag Assignment for the Example


| Filename | Tag | Description |
| ----- | ----- | ----- |
| anomaly/country-anomaly.lua | country | Flag rare countries |
| anomaly/signature-anomaly.lua | signature | Flag rare alerts |
| anomaly/time-anomaly.lua | time | Flag events at odd hours |
| blacklist/example-dns.lua | -- | Use abuse.ch blacklists for dns |
| blacklist/example-flow.lua | -- | |
| blacklist/example-tls.lua | -- | |
| event-triage/alert-dns-cache.lua | cache | |
| event-triage/alert-triage.lua | -- | |


