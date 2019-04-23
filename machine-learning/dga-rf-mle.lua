-- ----------------------------------------------
-- Copyright 2018, CounterFlow AI, Inc. 
-- 
-- Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following 
-- conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer 
--    in the documentation and/or other materials provided with the distribution.
-- 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products 
--    derived from this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
-- BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
-- SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
-- OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- author: Andrew Fast <af@counterflowai.com>
-- ----------------------------------------------

-- ----------------------------------------------
-- Analyzer to score DNS answers with a probility that the domain
-- was generated by a DGA
-- Includes the transform function and helper library (feature.lua)
-- for creating features from the domain that are useful for classification
--
-- This analyzer demonstrates the Redis-ML Random Forest model
-- ----------------------------------------------

local open = io.open
local dt = require('analyzer/feature') -- contains data transformation functions

-- ----------------------------------------------
-- Transform takes a domain and converts it to the format needed for Redis-ML
-- ----------------------------------------------
function transform(input)
	lowerdomain = input
	splits = csplit(lowerdomain, "%.")
	splitdomain = splits.parts
	numparts = splits.num

	parts = parse(splitdomain, numparts)

	newrow = {}
	newrow[1] = numparts  -- Number of domain parts
	newrow[2] = string.len(parts.tld) --Length of tld
	newrow[3] = string.len(parts.second) --Length of 2LD

	if newrow[2] == 0 then
		print (input)
	end

	newrow[4] = string.len(parts.third) --Length of 3LD

	if string.len(parts.third) > 0 then -- Has a 3LD
		newrow[5] = 1
	else
		newrow[5] = 0
	end

	if (numparts > 3 and string.len(parts.tld) <= 3) or numparts > 4  then --Has more than 3LD
		newrow[6] = 1
	else
		newrow[6] = 0
	end

	if string.len(parts.tld) < 3 then --Is just a country code
		newrow[7] = 1
	else
		newrow[7] = 0
	end

	if string.find(lowerdomain, ".edu", 1, true) then --Is this .edu
		newrow[8] = 1
	else
		newrow[8] = 0
	end

	if string.find(lowerdomain, ".gov", 1, true) or string.find(lowerdomain, ".govt", 1, true) or string.find(lowerdomain, ".gouv", 1, true) then --Is this .gov
		newrow[9] = 1
	else
		newrow[9] = 0
	end

	if parts.tld == "com" then --Is this .com
		newrow[10] = 1
	else
		newrow[10] = 0
	end

	if parts.tld == "net" then --Is this .net
		newrow[11] = 1
	else
		newrow[11] = 0
	end

	if parts.tld == "org" then --Is this .org
		newrow[12] = 1
	else
		newrow[12] = 0
	end

	if parts.tld == "info" then --Is this .info
		newrow[13] = 1
	else
		newrow[13] = 0
	end

	if parts.tld == "biz" then --Is this .biz
		newrow[14] = 1
	else
		newrow[14] = 0
	end

	-- Character Count based features
	charCounts = countAllChars(parts.second)
	fullCharCounts = countAllChars(lowerdomain)
	distinctChars = charCounts.distinct
	digitCount = (countDigits(charCounts) or 0)
	numDashes = (countChar(charCounts, "-") or 0)

	-- fullCharCounts = countAllChars(lowerdomain)
	-- distinctChars = fullCharCounts.distinct
	-- digitCount = (countDigits(fullCharCounts) or 0)
	-- numDashes = (countChar(fullCharCounts, "-") or 0)

	length = 1
	-- if string.len(lowerdomain) > 0 then
	if string.len(parts.second) > 0 then
		percentDistinct = (distinctChars/string.len(parts.second) or 0)
		percentDigits = (digitCount/string.len(parts.second) or 0)
	end

	newrow[15] = distinctChars -- Num of distinct characters
	newrow[16] = digitCount --Num of digits

	if digitCount > 0 then --has digit
		newrow[17] = 1
	else
		newrow[17] = 0
	end


	newrow[18] = numDashes

	if numDashes > 0 then --has dash
		newrow[19] = 1
	else
		newrow[19] = 0
	end

	newrow[20] = string.len(parts.last) --length of anything past 3
	newrow[21] = (percentDistinct or 0)
	newrow[22] = (percentDigits or 0)

	newrow[23] = metricEntropy(lowerdomain, fullCharCounts)

	return newrow
end
-- ----------------------------------------------
--
-- ----------------------------------------------
function setup()
	conn = hiredis.connect()
	assert(conn:command("PING") == hiredis.status.PONG)
	print (">>>>>>>> DGA (Random Forest) Analyzer")
	numTrees = 5
	mlpath = "/usr/local/dragonfly-mle/analyzer/dga-rf"
	
	-- Random Forest Model
	print ("Loading Random Forest model from file......")
	for i = 1,numTrees do
		treeFile = mlpath .. "-" .. i .. ".ml"
		print(treeFile)
		local file = open(treeFile, "rb") -- r read mode 
		local model = file:read ("*a")
		file:close()
		reply = conn:command_line("ML.FOREST.ADD " .. model)
	end
    print ("loaded ML model: ", reply)
end

-- ----------------------------------------------
--
-- ----------------------------------------------
function loop(msg)
	local eve = msg
	
	-- Note we're assuming you are using Suricata DNS logging version 2. 
	if eve and eve.dns.type == 'answer' and eve.dns.rrname and eve.dns.answers then
			local features = transform (eve.dns.rrname)

			command = {}
			names = getFeatureNames() -- Need to combine feature names together to call the Random Forest

			for i = 1,table.getn(features) do
				table.insert(command, names[i] .. ":" .. features[i])
			end


			local ml_command = "ML.FOREST.RUN" .. " " .. "dga:tree " .. table.concat(command, ",") .. " REGRESSION"
			reply = conn:command_line(ml_command)
			

			analytics = eve.analytics
			if not analytics then
				analytics = {}
			end
			
			dga = {}
			dga.score = reply
			dga.source = "dga/dga-rf-mle.lua"

			analytics.dga = dga
			eve.analytics = analytics
		
			dragonfly.output_event ("log", eve)
	else 
		dragonfly.output_event("log", msg)
	end
end
