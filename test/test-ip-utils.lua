require "analyzer/ip-utils"

testIP1 = "192.168.0.1"
testIP2 = "192.168.1.1"

print(GetIPType(testIP1))
print(IPv4ToLong(testIP1))
print(IPv4ToLong(testIP2))


-- readIP2Location("/Users/afast/data/ip2location/IP2LOCATION-LITE-DB1.CSV/IP2LOCATION-LITE-DB1.CSV")


print(IPv4ToLong("128.169.74.229"))

testStr = "United States:US:71892"

name, code = testStr:match("(.+):(.+):.+")
print(name)
print(code)