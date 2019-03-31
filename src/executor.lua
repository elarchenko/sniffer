i2c.setup(0, 1, 2, i2c.SLOW)

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

    local disp = u8g2.ssd1306_i2c_128x64_noname(0, 0x3c)

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
        disp:clearBuffer()
        disp:setPowerSave(0)
        --disp:setFont(u8g2.font_6x10_tf)
        disp:setFont(u8g2.font_fub25_tr)
        disp:setDrawColor(1)
        disp:setFontDirection(0)
        disp:drawStr(15, 30, string.format("%05.1f", co2))
        disp:sendBuffer()
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
        local json = ""
        if (content1 ~= nil) then
          json = json .. content1
        end
        if (content2 ~= nil) then
          json = json .. content2
        end
        if (content3 ~= nil) then
          json = json .. content3
        end
        if (content4 ~= nil) then
          json = json .. content4
        end
        latestMeasurements = sjson.decode(json)
        file.close()
        print("Measuremets loaded: ", tableSize(latestMeasurements))
      end
    end
    
    loadData()
    
    -- configure reading of MHZ19
    gpio.mode(MHZ19_PIN, gpio.INT)
    gpio.trig(MHZ19_PIN, TRIGGER_ON, mhz19InterruptHandler)

end