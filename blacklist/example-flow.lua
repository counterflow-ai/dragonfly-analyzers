-- ----------------------------------------------
-- Copyright (c) 2018, CounterFlow AI, Inc. All Rights Reserved.
-- author: Randy Caldejon <rc@counterflowai.com>
--
-- Use of this source code is governed by a BSD-style
-- license that can be found in the LICENSE.txt file.
-- ----------------------------------------------

-- ----------------------------------------------
-- On setup, download ipblocklist from abuse.ch
-- On loop, check for membership in the list, and cache the results
-- ----------------------------------------------
filename = "badip.txt"
file_url = "https://zeustracker.abuse.ch/blocklist.php?download=ipblocklist"
redis_key = "bad.ip"
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
	http_get (file_url, filename)
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
	print (">>>>Bad IP analyzer running")
end

-- ----------------------------------------------
--
-- ----------------------------------------------
function loop(msg)
	local eve = cjson.decode(msg)
		if eve and eve.event_type == "flow" and conn:command("SISMEMBER",redis_key, eve.dest_ip) == 1 then
			message = "time: "..eve.timestamp..", dest_ip: "..eve.dest_ip..", flow_id: "..eve.flow_id..", alerted: "..tostring(eve.flow.alerted)
			print ("flow-alert: "..message)
			dragonfly.output_event ("flow", message)
			--ip_reputation (eve.timestamp, "blacklist", eve.dns.rdata, 300)
		end

end

