-- ----------------------------------------------
-- Copyright (c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Randy Caldejon <rc@counterflowai.com>

-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- ----------------------------------------------
-- On setup, download domainblocklist from abuse.ch
-- On loop, check for membership in the list, and cache the results using Redis set
-- ----------------------------------------------
filename = "baddomains.txt"
file_url = "https://zeustracker.abuse.ch/blocklist.php?download=baddomains"
redis_key = "bad.domain"
-- ----------------------------------------------
--
-- ----------------------------------------------
function setup()
	conn = hiredis.connect()
	if not conn then
		error ("Error connecting to the redis server")
	end
	if conn:command("PING") ~= hiredis.status.PONG then
		error ("Unable to ping redis")		
	end
	dragonfly.http_get (file_url, filename)
	local file, err = io.open(filename, 'rb')
	if file then
		conn:command("DEL",redis_key)
		while true do
			line = file:read()
			if line ==nil then
				break
			elseif line ~='' and not line:find("^#") then
				if (conn:command("SADD",redis_key,line)==1) then
					print (line)
				end
			end
		end
	end
	print (">>>> Bad DNS analyzer running")
end

-- ----------------------------------------------
--
-- ----------------------------------------------
function loop(msg)
	local eve = cjson.decode(msg)
	if eve and eve.dns.type == 'answer' and eve.dns.answers and eve.dns.rrname then
		if conn:command("SISMEMBER",redis_key,eve.dns.rrname) == 1 then
			message = "rrname: "..eve.dns.rrname..", rdata: ".. eve.dns.answers[1].rdata
			-- print ("dns-alert: "..message)
			dragonfly.output_event ("dns", message)
		end
	end
end

