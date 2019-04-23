function setup()
	print ("Signature Test filter running")
end

function loop(msg)
    local eve = msg
    if eve then
        dragonfly.analyze_event(default_analyzer, msg)
    end
end
