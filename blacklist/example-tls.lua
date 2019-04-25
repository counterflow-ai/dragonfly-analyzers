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
-- ----------------------------------------------



-- ----------------------------------------------
-- TLS look up -- https://notary.icsi.berkeley.edu/
-- ----------------------------------------------

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
		else
			print (">>>>TLS analyzer running")
		end
end

-- ----------------------------------------------
--
-- ----------------------------------------------
function loop(msg)
	local eve = cjson.decode(msg)
	if eve.tls.fingerprint then
		local sha1 = string.gsub(eve.tls.fingerprint, ":", "")
		if sha1 then
		    -- print ("TLS fingerprint: "..eve.tls.fingerprint)
			key = "tls:"..sha1
			conn:command ("hmset", key, "issuerdn",eve.tls.issuerdn,"subject",eve.tls.subject,"version", eve.tls.version)
			conn:command ("expire", key,'300')
			conn:command ("zincrby", "tls",1,sha1)
			reply =  conn:command ("sismember","tls:valid",sha1) 
			if reply then
				local a_record = sha1..".notary.icsi.berkeley.edu"
				---print(">> TLS CHECKING: "..a_record)
				local ip = dnslookup(a_record) 
				if not ip[1] then
					message = "time: "..eve.timestamp..", message: TLS lookup error - "..status
					-- print (message)
					dragonfly.output_event ("log", message)
				else
					-- print(">> TLS RESP: "..ipi[1])
					if ip[1] == "127.0.0.2" or ip[1] == "127.0.0.1" then
						conn:command("sadd","tls:valid",sha1) 
						conn:command ("expire", key,'300')
					else
						message = "time:"..eve.timestamp..", dest ip:"..eve.dest_ip.."fingerprint:"..sha1..", issuer: "..eve.tls.issuerdn..", subject:"..eve.tls.subject.."sni:"..eve.tls.sni
						dragonfly.output_event ("tls", message)
					end
				end
			end
		end
	end
end
