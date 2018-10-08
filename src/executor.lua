do
    local MHZ19_PIN = 3
    local TRIGGER_ON = "both"
    local SEND_INTERVAL_MS = 10 * 1000

    local lowDuration = 0
    local highDuration = 0
    local lastTimestamp = 0
    
    local started = 0
    local latest = nil
    local each = 15

    local latestMeasurements = {}

    local function calculateCo2Ppm(highDuration, lowDuration)
      return 5000.0 * (1002.0 * highDuration - 2.0 * lowDuration) / 1000.0 / (highDuration + lowDuration);
    end
    
    local function saveData()
      st_string = sjson.encode(latestMeasurements)
      if (file.open("data.json", "w+")) then
        file.write(st_string)
        file.close()
      end
    end
    
    function tableSize(T)
      local count = 0
      for _ in pairs(T) do count = count + 1 end
      return count
    end
    
    local function addData(timestamp, co2)
      local dt = rtctime.epoch2cal(timestamp)
      if ((latest == nil) or ((dt["min"] % each) < latest)) then
        local el = {}
        el.x = string.format("%04d-%02d-%02d %02d:%02d", dt["year"], dt["mon"], dt["day"], dt["hour"], dt["min"])
        el.y = co2
        if (tableSize(latestMeasurements) > 99) then
          for i=1,99 do
            latestMeasurements[i] = latestMeasurements[i+1]
          end
          latestMeasurements[100] = el
        else
          latestMeasurements[tableSize(latestMeasurements) + 1] = el
        end
        if (latest ~= nil) then
          saveData()
        end
      end
      latest = dt["min"] % each
    end

    local function mhz19InterruptHandler(level, timestamp)
      --print("mhz19InterruptHandler", level, timestamp)
      if (level == gpio.LOW) then
        highDuration = timestamp - lastTimestamp
      else
        lowDuration = timestamp - lastTimestamp
        local co2 = calculateCo2Ppm(highDuration, lowDuration)
        if (started == 0) then
          if ((co2 >= 500) and (co2 < 2000)) then
            started = 1
          end
        else
          addData(rtctime.get(), co2)
        end
        print("co2", co2)
      end
      lastTimestamp = timestamp
    end
    
    local function loadData()
      if (file.open("data.json", "r")) then
        local content1 = file.read()
        file.seek("set", 1024)
        local content2 = file.read()
        file.seek("set", 2048)
        local content3 = file.read()
        file.seek("set", 3072)
        local content4 = file.read()
        latestMeasurements = sjson.decode(content1 .. content2 .. content3 .. content4)
        file.close()
      end
    end
    
    loadData()
    
    -- configure reading of MHZ19
    gpio.mode(MHZ19_PIN, gpio.INT)
    gpio.trig(MHZ19_PIN, TRIGGER_ON, mhz19InterruptHandler)

end