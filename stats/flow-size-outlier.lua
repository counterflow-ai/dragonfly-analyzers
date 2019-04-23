-- ----------------------------------------------
-- Copyright 2018, CounterFlow AI, Inc. 
-- Author: Andrew Fast <af@counterflowai.com>
-- ----------------------------------------------

require 'math'

local mad_id = "tot_bytes_mad"
local DEVIATION_MULTIPLE = 5

function setup()
    conn = hiredis.connect()
    assert(conn:command("PING") == hiredis.status.PONG)
    starttime = 0 --mle.epoch()
    print (">>>>>>>> MAD Packets Analyzer")
    local cmd = 'HMSET '..mad_id..':median current NaN median NaN learning_rate 0.05 count 0'
    local reply = conn:command(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(cmd..' : '..reply.name)
    end 

    local cmd = 'HMSET '..mad_id..':deviation current NaN median NaN learning_rate 0.05 count 0'
    local reply = conn:command_line(cmd)
    if type(reply) == 'table' and reply.name ~= 'OK' then
        dragonfly.log_event(cmd..' : '..reply.name)
    end 
end


-- ----------------------------------------------
-- Use streaming Median Absolute Deviation (MAD) for outlier detection.
-- This requires two streaming median computations one for the actual median, and one for the median of the deviations
-- We are using a streaming, stochastic estimate of the median that does not require
-- storing the entire data to compute
-- See Real-Time Analytics , Byron Ellis (Wiley 2014), pg296 for more information
-- ----------------------------------------------
function loop(eve)
    if eve and eve.event_type == 'flow' and (eve.proto=='TCP' or eve.proto=='UDP') then
        -- extract the fields
        total_pkts = eve.flow.pkts_toclient + eve.flow.pkts_toserver
        total_bytes = eve.flow.bytes_toclient + eve.flow.bytes_toserver

        -- Update the Median
        last_median = update_median(mad_id .. ":median", total_bytes) -- Returns median prior to the update so that it is not skewed by the current value
        if not last_median then
            dragonfly.analyze_event(default_analyzer, eve)
            return
        end

        abs_deviation = math.abs(last_median - total_bytes) -- Compute deviation 

        last_median_deviation = update_median(mad_id .. ":deviation", abs_deviation)
        multiple = abs_deviation / last_median_deviation

        local cmd = 'HMGET '..mad_id .. ':median count'
        local reply = conn:command_line(cmd)
        for _,v in ipairs(reply) do
            if type(v) == 'table' and v.name ~= 'OK' then
                dragonfly.log_event(cmd..' : '..v.name)
            elseif not tonumber(v) then
                dragonfly.log_event('Could not convert to number: '..v)
            end
        end
        local count = reply

        if multiple ~= multiple or multiple == math.huge then
            multiple = -1
        end

         if last_median ~= last_median or last_median == math.huge then
            last_median = -1
        end

        if last_median_deviation ~= last_median_deviation or last_median_deviation == math.huge then
            last_median_deviation = -1
        end

        if abs_deviation ~= abs_deviation or abs_deviation == math.huge then
            abs_deviation = -1
        end

        analytics = eve.analytics
        if not analytics then
            analytics = {}
        end
        bytes_mad = {}
        bytes_mad["since"] = starttime
        bytes_mad["n"] = (tonumber(count[1]) or 'N/A')
        bytes_mad["median"] = last_median
        bytes_mad["median_deviation"] = last_median_deviation
        bytes_mad["deviation"] = abs_deviation
        bytes_mad["multiple"] = multiple
        bytes_mad["source"] = "example-outlier.lua"

        -- print("t=" .. starttime .. " n=" .. bytes_mad["n"] .. " m=" .. last_median .. " md=" .. last_median_deviation .. " d=" .. abs_deviation .. " x=" .. multiple)

        analytics["bytes_mad"] = bytes_mad
        eve["analytics"] = analytics

        dragonfly.analyze_event(default_analyzer, eve) 
    else 
        dragonfly.analyze_event("sink", eve)
    end
end

function update_median(full_key, value)
    local cmd = 'HMGET '..full_key..' current median learning_rate count'
    local values = conn:command(cmd)
    for _,v in ipairs(values) do
        if type(v) == 'table' and v.name ~= 'OK' then
            dragonfly.log_event(cmd..' : '..v.name)
            return nil
        elseif not tonumber(v) then
            dragonfly.log_event('Could not convert to number : '..v)
            return nil
        end
    end
    current = tonumber(values[1])
    median = tonumber(values[2])
    old_median = median
    learning_rate = tonumber(values[3])
    new_count = tonumber(values[4]) + 1

    if (value ~= median) then -- only update of median is different than current value
        if (median ~= median) then -- check for NaN
            median = tonumber(value)
        else 
            median = median + (median < tonumber(value) and learning_rate or -learning_rate) -- update median 
        end
        local cmd = 'HMSET '..full_key..' current '..value..' median '..median..' count '..new_count
        reply = conn:command(cmd)
        if type(reply) == 'table' and reply.name ~= 'OK' then
            dragonfly.log_event(cmd..' : '..reply.name)
        end 
    end
    return old_median
end
