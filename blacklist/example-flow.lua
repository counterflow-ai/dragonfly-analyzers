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
-- author: Randy Caldejon <rc@counterflowai.com>
-- ----------------------------------------------)

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

