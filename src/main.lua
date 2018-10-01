dofile("wifi.lua")

tmr.alarm(2,1000,1,function()
  if connected==1 then
    tmr.stop(2)
    sntp.sync(nil, function(sec, usec, server, info) rtctime.set(sec + 18000) end, sntp_sync_time, 1)
    dofile("web.lua")
    --local exec = require("executor")
    --exec.init()
    dofile("executor.lua")
  end
end)