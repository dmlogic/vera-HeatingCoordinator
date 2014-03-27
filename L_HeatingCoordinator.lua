local hcTotalDevices = 0
local hcCoordinatorServiceId = 'urn:dmlogic-com:serviceId:HeatingCoordinator1'
local hcSetPointServiceId    = 'urn:upnp-org:serviceId:TemperatureSetpoint1_Heat'
local hcCurrentTempServiceId = 'urn:upnp-org:serviceId:TemperatureSensor1'
local hcRelayServiceId       = 'urn:upnp-org:serviceId:HVAC_UserOperatingMode1'
local hcTooSoonSeconds = 120 -- every 2 mins is just fine
local hcDeviceMap = {}
local hcRelayId = 33
local hcControllerId = 66
local hcTimerDelay = "2m"

function hcDeviceNeedsHeat(deviceId)

    setPoint = luup.variable_get(hcSetPointServiceId,'CurrentSetpoint', deviceId)
    current  = luup.variable_get(hcCurrentTempServiceId,'CurrentTemperature', deviceId)

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

function hcTooSoon(controllerId)

    -- luup.log("CRAZY FOOL. TURN TOO SOON BACK ON ",25)
    -- return false

    last = luup.variable_get(hcCoordinatorServiceId,'lastRelaySetTime',controllerId)

    if(last == nil) then
        hcLogLastSet(controllerId)
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

function hcLogLastSet(controllerId,t)
    setTime = t or os.time()
    luup.variable_set(hcCoordinatorServiceId,'lastRelaySetTime',setTime,controllerId)
end

--[[
  Do your thang
]]--
function hcProcess(relayId)

    if(hcTooSoon(hcControllerId) == true) then
        return 'tooSoon'
    end

    hcLogLastSet(hcControllerId)

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

    -- luup.log("hcMonitor lul_device:"..lul_device..", lul_variable:"..lul_variable..", lul_value_old:"..lul_value_old..", lul_value_new:"..lul_value_new.." at ".. os.date("%H:%M:%S"),25)

    -- We've changed a setpoint, sync the valves
    if(lul_variable == "CurrentSetpoint") then
        hcSetValveSetPoint(hcDeviceMap[lul_device],lul_value_new)
    end

    -- As we're here anyway, let's check the boiler
    hcProcess(hcRelayId);

end

--[[
    Assigns a setpoint to all the valveIds
]]
function hcSetValveSetPoint(valveIds,setPoint)

    for k,valveId in pairs(valveIds) do
        -- luup.log("hcSetValveSetPoint:"..valveId..", "..setPoint,25)

        args = {}
        args.NewCurrentSetpoint = setPoint
        luup.call_action(hcSetPointServiceId,'SetCurrentSetpoint',args,valveId)

    end
end

--[[
    Statup routine
]]
function hcSyncStatsAndValves()

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

    luup.call_timer("hcTimer", 1, hcTimerDelay, "", "data")

    luup.log("hcTimer ran at ".. os.date("%H:%M:%S"),25)
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
function hcStartup(lul_device, relayId, controllerId)

    luup.task("Running Lua Startup", 1, "HeatingCoordinator", -1)

    -- This allows us to unit test
    if(type(lul_device) == 'table') then

        hcDeviceMap = lul_device

    -- This is the default Map of stat IDs to rad valves
    else
        hcControllerId = lul_device

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

    if(controllerId ~= nil) then
        hcControllerId = controllerId
    end

    -- Listen to the stats
    hcSetupEventListening()

    -- Run the timer for the first time
    hcTimer()

    luup.log("hcStartup started monitoring at ".. os.date("%H:%M:%S"),25)

end
