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
--[[
Feature Creation is a series of functions to transform the domain string
into a model friendly format

Functions to create the following features:
	- Identify domain parts: TLD (.com or .co.uk etc.), 2LD, 3LD
	- Count dots - how many domain parts are there
	- Length of domain parts
	- Distinct character count
	- Digit count
	- Percent digits
	- Percent distinct characters
	- Character Entropy
	- And more...
]]
-- ----------------------------------------------

require 'string'
require 'math'

-- ----------------------------------------------
-- Function from http://lua-users.org/wiki/SplitJoin
-- Simple split on delimeter (does not escape csv)
-- ----------------------------------------------
function csplit(str,sep)
   local ret={}
   local n=1
   for w in str:gmatch("([^"..sep.."]*)") do
      ret[n] = ret[n] or w -- only set once (so the blank after a string is ignored)
      if w=="" then
         n = n + 1
      end -- step forwards on a blank but not a string
   end
   result = {parts=ret, num = n - 1}
   return result
end
-- ----------------------------------------------
-- Function:  Count all specific characters
-- ----------------------------------------------
function countAllChars(s) 
	charCounts = {}
	numDistinctChars = 0
	--print(string.len(s))

	for i = 1,string.len(s) do
		currChar = string.sub(s,i,i)
		--print(currChar)
		currCount = 0
		if charCounts[currChar] then
			currCount = charCounts[currChar] + 1
		else 
			numDistinctChars = numDistinctChars + 1
			currCount =  1
		end
		charCounts[currChar] = currCount
	end
	charCounts["distinct"] = numDistinctChars
	return(charCounts)
end
-- ----------------------------------------------
-- Count a specific char, depends on the count table produced by countAllChars
-- ----------------------------------------------
function countChar(countTable, charToCount)
	return(countTable[charToCount] or 0)
end

function countDigits(countTable)
	total = 0
	for i = 1,9 do
		if countTable[i .. ""] then
			total = total + countTable[i .. ""]
		end
	end
	return(total)
end
-- ----------------------------------------------
-- Shannon Entropy 
-- ----------------------------------------------
function shannonEntropy(origString, charCounts)
	strLength = string.len(origString)
	entropy = 0
	for k,v in pairs(charCounts) do
		if not(k == "distinct") then
			-- print(k .. " " .. v)
			fraction = v/strLength
			-- print(fraction)
			entContrib = (fraction * (math.log(fraction)/math.log(2)))
			-- print(entContrib)
			entropy = entropy + entContrib
		end
	end
	return(entropy * -1)
end
-- ----------------------------------------------
-- Normalized Shannon Entropy
-- ----------------------------------------------
function metricEntropy(origString, charCounts)
	strLength = string.len(origString)
	return(shannonEntropy(origString, charCounts)/strLength)
end
-- ----------------------------------------------
-- Function to produce a table with parts of the domain
-- ----------------------------------------------
function parse(splitdomain, numparts)
	tld = ""
	second = ""
	third = ""
	last = ""

	if numparts >= 2 and not(numparts > 2 and splitdomain[numparts] == "arpa" and splitdomain[numparts-1] == "in-addr") then
		-- If length of last spot is 2, and length of second to last spot is < 3, then assume a compound tld
		tldlength = 1
		if numparts > 2 and string.len(splitdomain[numparts]) == 2 and string.len(splitdomain[numparts-1]) <= 3 then
			tldlength = 2
			tld = splitdomain[numparts-1] .. "." .. splitdomain[numparts]
		else
			tld = splitdomain[numparts]
		end

		second = splitdomain[numparts - tldlength]

		if numparts > tldlength + 1 then
			third = splitdomain[numparts-(tldlength+1)]
		end
	end 

	retval = {}
	retval["tld"] = tld
	retval["second"] = second
	retval["third"] = third
	retval["last"] = splitdomain[numparts]
	return retval
end
-- ----------------------------------------------
-- Helper for building random forest model 
-- ----------------------------------------------
function getFeatureNames() 
	names = {"num_parts", "len_tld", "len_2ld", "len_3ld", "has_3ld", "more_than_3ld",
              "two_letter_tld", "is_edu", "is_gov", "is_com", "is_net", "is_org", "is_info",
              "is_biz", "distinct_char", "digit_count", "has_digit", "num_dashes", "has_dash",
			  "length_extra", "percent_distinct", "percent_digits", "entropy"}
	return names
end
