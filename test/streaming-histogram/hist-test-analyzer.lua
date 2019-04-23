
require 'analyzer/streaming-histogram'

function setup()
    conn = hiredis.connect()
    assert(conn:command("PING") == hiredis.status.PONG)
    hist_key = "test_histogram"
    numBins = 5
    conn:command_line('HSET test_histogram 0 0')
    print (">>>>>>>> Test Histogram Analyzer")
end


function loop(msg)
    local point = msg
    if point and point.point then
        histogram = histogram_update(conn, hist_key, point.point, 5)
        for k,v in pairs(histogram) do 
            dragonfly.output_event("debug", "return value " .. tostring(k) .. " " .. v)
        end
        d = histogram_density(conn, hist_key, 3)
        output = {}
        output["point"] = point.point
        output["hist"] = histogram
        output["density"] = "3->" .. d
        dragonfly.output_event("log", output)
    else
        dragonfly.output_event("debug", "Unable to parse msg: " .. msg)
    end

end
