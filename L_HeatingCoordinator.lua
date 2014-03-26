local hcTotalDevices = 0
local hcCoordinatorServiceId = 'urn:dmlogic-com:serviceId:HeatingCoordinator1'
local hcSetPointServiceId    = 'urn:upnp-org:serviceId:TemperatureSetpoint1_Heat'
local hcCurrentTempServiceId = 'urn:upnp-org:serviceId:TemperatureSensor1'
local hcRelayServiceId       = 'urn:upnp-org:serviceId:HVAC_UserOperatingMode1'
local hcTooSoonSeconds = 120 -- every 2 mins is just fine
local hcDeviceMap = {}
local hcRelayId = 33
local hcTimerDelay = "2m"

function hcDeviceNeedsHeat(deviceId)

    local setPoint = tonumber(luup.variable_get(hcSetPointServiceId,'CurrentSetpoint', deviceId))
    local current  = tonumber(luup.variable_get(hcCurrentTempServiceId,'CurrentTemperature', deviceId))

    -- luup.log("hcDeviceNeedsHeat "..deviceId,25)

    if (setPoint == nil or  current == nil) then
        return false
    end

    if(current < setPoint) then
        return true
    end

    return false
end

function hcSetRelay(setValue,relayId)

    -- note when last set
    hcLogLastSet(relayId)

    args = {}
    args.NewModeTarget = setValue

    luup.log("hcSetRelay "..relayId.." to "..setValue.." at "..os.date("%H:%M:%S"),25)

    -- set the relay
    -- http://192.168.1.104:3480/data_request?id=action&DeviceNum=33&serviceId=urn:upnp-org:serviceId:HVAC_UserOperatingMode1&action=SetModeTarget&NewModeTarget=Off
    -- http://192.168.1.104:3480/data_request?id=variableget&DeviceNum=33&Variable=ModeStatus&serviceId=urn:upnp-org:serviceId:HVAC_UserOperatingMode1
    return luup.call_action(hcRelayServiceId,'SetModeTarget',args,relayId)

end

function hcTooSoon(relayId)

    -- luup.log("CRAZY FOOL. TURN TOO SOON BACK ON ",25)
    -- return false

    last = tonumber(luup.variable_get(hcCoordinatorServiceId,'lastRelaySetTime',relayId))

    if(last == nil) then
        hcLogLastSet(relayId)
        return false
    end

    now = os.time()
    diff = now - last

    if(diff < hcTooSoonSeconds) then
        return true
    else
        return false
    end
end

function hcLogLastSet(relayId,t)
    setTime = t or os.time()
    luup.variable_set(hcCoordinatorServiceId,'lastRelaySetTime',setTime,relayId)
end

--[[
  Do your thang
]]--
function hcProcess(relayId)


    if(hcTooSoon(relayId) == true) then
        luup.log("hcProcess too soon",25)
        return 'tooSoon'
    end

    luup.log("hcProcess",25)
    hcLogLastSet(relayId)

    -- loop our devices and see if anyone needs heat
    for k,v in pairs(hcDeviceMap) do

        -- Yep, boiler on
        if(hcDeviceNeedsHeat(k)) then
            hcSetRelay('HeatOn',relayId)
            return 'heatOn'
        end
    end

    -- nope, boiler off
    hcSetRelay('Off',relayId)
    return 'heatOff'

end

--[[
    This is what fires when an event happens
]]
function hcMonitor(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)

    -- We've changed a setpoint, sync the valves
    if(lul_variable == "CurrentSetpoint") then
        hcSetValveSetPoint(hcDeviceMap[lul_device],lul_value_new)
    end

    -- As we're here anyway, let's check the boiler
    hcProcess(hcRelayId);

    luup.log("DMHeating lul_device:"..lul_device..", lul_variable:"..lul_variable..", lul_value_old:"..lul_value_old..", lul_value_new:"..lul_value_new.." at ".. os.date("%H:%M:%S"),25)
end

--[[
    Assigns a setpoint to all the valveIds
]]
function hcSetValveSetPoint(valveIds,setPoint)

    for k,valveId in pairs(valveIds) do
        -- luup.log("DMHeating hcSetValveSetPoint:"..valveId..", "..setPoint,25)
        luup.variable_set(hcSetPointServiceId,"CurrentSetpoint",setPoint,valveId)
    end
end

--[[
    Statup routine
]]
function hcSyncStatsAndValves( )

    -- Loop the map
    for statId,valveIds in pairs(hcDeviceMap) do

        -- -- Assign each setpoint to the corresponding valve
        hcSetValveSetPoint(valveIds, luup.variable_get(hcSetPointServiceId,"CurrentSetpoint",statId));
    end

end

--[[
    Share the scope for testing
]]
function hcGetDeviceMap( )
    return hcDeviceMap;
end

--[[
    Timer handler
]]
function hcTimer()

    hcSyncStatsAndValves()

    hcProcess(hcRelayId);

    luup.call_timer("hcTimer", 1, hcTimerDelay, "", "")
end

function hcSetupEventListening()

    for statId,valveIds in pairs(hcDeviceMap) do

        -- Watches each stat for changing setpoint or room temperature
        luup.variable_watch("hcMonitor",hcSetPointServiceId,"CurrentSetpoint", statId); -- this works
        luup.variable_watch("hcMonitor",hcCurrentTempServiceId,"CurrentTemperature", statId); -- YES!

    end

end

--[[
    Startup function.
    Receives a map or sets the default
]]
function hcStartup(lul_device, relayId)

    luup.task("Running Lua Startup", 1, "HeatingCoordinator", -1)

    -- This allows us to unit test
    if(type(lul_device) == 'table') then

        hcDeviceMap = lul_device

    -- This is the default Map of stat IDs to rad valves
    else
        -- Hallway
        hcDeviceMap[39]  = {46,42,44,48,50,52,54,56,60}
        -- Kitchen
        -- hcDeviceMap[x] = {y}
        -- WC
        -- hcDeviceMap[x] = {y}
        -- Dining room
        -- hcDeviceMap[x] = {y}
        -- Lounge
        -- hcDeviceMap[x] = {y}
        -- Office
        hcDeviceMap[65] = {62,58}
        -- Master bedroom
        -- hcDeviceMap[x] = {y}
        -- Flo room
        -- hcDeviceMap[x] = {y}
        -- Spare room
        -- hcDeviceMap[x] = {58}
        -- Bathroom
        -- hcDeviceMap[x] = {y}
    end

    -- Test relay or default
    if(relayId ~= nil) then
        hcRelayId = relayId
    end

    -- Listen to the stats
    hcSetupEventListening()

    -- Run the timer for the first time
    hcTimer()

    luup.log("DMHeating hcStartup started monitoring at ".. os.date("%H:%M:%S"),25)

end
