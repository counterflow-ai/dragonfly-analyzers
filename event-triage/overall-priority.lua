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

require 'math'
require 'analyzer/utils'

local analyzer_name = 'Overall Priority'

function setup()
    conn = hiredis.connect()
    if conn:command('PING') ~= hiredis.status.PONG then
        dragonfly.log_event(analyzer_name..': Could not connect to redis')
        dragonfly.log_event(analyzer_name..': exiting')
        os.exit()
    end
    starttime = 0 --mle.epoch()
    print (">>>>>>>> Overall Priority")
end

function get_bytes_rank(eve)
    -- Analyzer 5: Bytes Rank Percentile
    -- Threshold: 0.95 
    bytes_rank = {}
    threshold = 0.95 -- 95% percentile
    bytes_rank['threshold'] = threshold

    dest_percentile = 0

    local cmd = 'ZRANK total_bytes_rank:dest '..eve.dest_ip
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg) 
        return
    elseif not tonumber(reply) then
        dragonfly.log_event(analyzer_name..': Could not convert to number: '..reply)
        dragonfly.analyze_event(default_analyzer, msg) 
        return
    end 
    local dest_rank = reply

    local cmd = 'ZCARD total_bytes_rank:dest'
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg) 
        return
    elseif not tonumber(reply) then
        dragonfly.log_event(analyzer_name..': Could not convert to number: '..reply)
        dragonfly.analyze_event(default_analyzer, msg) 
        return
    end 
    local dest_size = reply


    src_percentile = 0
    local cmd = 'ZRANK total_bytes_rank:src '..eve.src_ip
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg) 
        return
    elseif not tonumber(reply) then
        dragonfly.log_event(analyzer_name..': Could not convert to number: '..reply)
        dragonfly.analyze_event(default_analyzer, msg) 
        return
    end 
    local src_rank = reply

    local cmd = 'ZCARD total_bytes_rank:src'
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(analyzer_name..': '..cmd..' : '..reply.name)
        dragonfly.analyze_event(default_analyzer, msg) 
        return
    elseif not tonumber(reply) then
        dragonfly.log_event(analyzer_name..': Could not convert to number: '..reply)
        dragonfly.analyze_event(default_analyzer, msg) 
        return
    end 
    local src_size = reply

    dest_percentile = tonumber(dest_rank) / tonumber(dest_size)
    src_percentile = tonumber(src_rank) / tonumber(src_size)
    score = math.max(dest_percentile, src_percentile)

    bytes_rank["score"] = score
    bytes_rank["threshold"] = threshold
    bytes_rank["src_percentile"] = src_percentile
    bytes_rank["dest_percentile"] = dest_percentile
    return bytes_rank
end

function loop(msg)
    local start = os.clock()
    local eve = msg
	local fields = { ["event_type"] = "alert"}
    if not check_fields(eve, fields) then
        dragonfly.log_event(analyzer_name..': Required fields missing')
        dragonfly.analyze_event(default_analyzer, msg)
        return
    end
    analytics = eve.analytics
    details = {}
    max_score = 0
    score = 0
    num_over_threshold = 0
    num_analyzers = 0
    -- Add in individual analyzers
    -- Aggregation function:  MAX of analyzers over the threshold + count of analyzers over the threshold

    -- Analyzer 1: Domain Generation Algorithm (DGA)
    -- Threshold: 0.98
    if analytics.dga then
        dga = {}
        score_str = analytics.dga.score
        dga_score = tonumber(score_str)
        dga["score"] = dga_score
        dga["domain"] = analytics.dga.domain

        if dga_score > 0.98 then
            num_over_threshold = num_over_threshold + 1
        end
        
        if dga_score > max_score then
            max_score = dga_score
        end
        num_analyzers = num_analyzers + 1
        details["dga"] = dga
    end

    -- Analyzer 2: IP Blacklist
    -- Threshold: 0, any non-NONE value = 1 
    if analytics.ip_rep and analytics.ip_rep.ip_rep then
        blacklist = {}
        reputation = analytics.ip_rep.ip_rep
        -- dragonfly.output_event("debug", "Score Rep: " .. reputation)
        blacklist["blacklist"] = reputation

        if reputation and reputation ~= "NONE" then
            num_over_threshold = num_over_threshold + 1
            max_score = 1
        end
        num_analyzers = num_analyzers + 1
        details["blacklist"] = blacklist
    end

    -- Analyzer 3: Time Anomaly 
    -- Threshold: Uniform (but set by the analyzer) 
    if analytics.time then
        time = {}
        threshold = analytics.time.threshold
        score = analytics.time.score
        -- dragonfly.output_event("debug", "Score Rep: " .. reputation)
        time["score"] = score
        time["threshold"] = threshold
        time["hour"] = analytics.time.hour
        time["timezone"] = analytics.time.timezone

        if score > threshold then
            num_over_threshold = num_over_threshold + 1
        end

        if score > max_score then
             max_score = score
        end
        num_analyzers = num_analyzers + 1
        details["time"] = time
    end

    -- Analyzer 4: Country Anomaly 
    -- Threshold: Uniform (but set by the analyzer) 
    if analytics.country then
        country = {}
        threshold = analytics.country.threshold
        score = analytics.country.score
        -- dragonfly.output_event("debug", "Score Rep: " .. reputation)
        country["score"] = score
        country["threshold"] = threshold
        country["country"] = analytics.country.country_code

        if score > threshold then
            num_over_threshold = num_over_threshold + 1
        end

        if score > max_score then
             max_score = score
        end
        num_analyzers = num_analyzers + 1
        details["country"] = country
    end


    local bytes_rank = get_bytes_rank(eve)
    if bytes_rank then
        if bytes_rank.score > bytes_rank.threshold then
            num_over_threshold = num_over_threshold + 1
        end

        if bytes_rank.score > max_score then
            max_score = score
        end
        num_analyzers = num_analyzers + 1
        details["bytes_rank"] = bytes_rank
    end
    
    -- Analyzer 6: Signature Anomaly
    if analytics.signature then
        signature = {}
        threshold = analytics.signature.threshold
        score = analytics.signature.score
        -- dragonfly.output_event("debug", "Score Rep: " .. reputation)
        signature["score"] = score
        signature["threshold"] = threshold

        if score > threshold then
            num_over_threshold = num_over_threshold + 1
        end

        if score > max_score then
             max_score = score
        end
        num_analyzers = num_analyzers + 1
        details["signature"] = signature
    end

    priority = {}
    -- Priority is max score, boosted if an analyzer crossed a threshold
    priority["priority"] = max_score + (max_score *  num_over_threshold / num_analyzers) 
    priority["details"] = details
    eve["priority"] = priority
    dragonfly.analyze_event(default_analyzer, eve) 
    local now = os.clock()
    local delta = now - start
    dragonfly.log_event(analyzer_name..': time: '..delta)
end
