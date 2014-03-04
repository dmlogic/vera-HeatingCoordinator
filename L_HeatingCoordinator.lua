local hcTotalDevices = 0
local hcCoordinatorServiceId = 'urn:dmlogic-com:serviceId:HeatingCoordinator1'
local hcSetPointServiceId    = 'urn:upnp-org:serviceId:TemperatureSetpoint1_Heat'
local hcCurrentTempServiceId = 'urn:upnp-org:serviceId:TemperatureSensor1'
local hcRelayServiceId       = 'urn:upnp-org:serviceId:HVAC_UserOperatingMode1'
local hcTooSoonSeconds = 120 -- every 2 mins is just fine
local hcDeviceMap = {}
local hcRelayId = 42

function hcDeviceNeedsHeat(deviceId)

    local setPoint = luup.variable_get(hcSetPointServiceId,'SetpointTarget', deviceId)
    local current  = luup.variable_get(hcCurrentTempServiceId,'CurrentTemperature', deviceId)

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

    -- set the relay
    -- http://192.168.1.104:3480/data_request?id=action&DeviceNum=42&serviceId=urn:upnp-org:serviceId:HVAC_UserOperatingMode1&action=SetModeTarget&NewModeTarget=Off
    -- http://192.168.1.104:3480/data_request?id=variableget&DeviceNum=42&Variable=ModeStatus&serviceId=urn:upnp-org:serviceId:HVAC_UserOperatingMode1
    return luup.call_action(hcRelayServiceId,'SetModeTarget',args,relayId)

end

function hcTooSoon(relayId)

    last = luup.variable_get(hcCoordinatorServiceId,'lastRelaySetTime',relayId)

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

    luup.log("hcProcess",25)

    if(hcTooSoon(relayId) == true) then
        return 'tooSoon'
    end

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
        luup.variable_set(hcSetPointServiceId,"CurrentSetpoint",setPoint,valveId)
    end
end

--[[
    Statup routine
]]
function hcInitDeviceMap( )

    -- Loop the map
    for statId,valveIds in pairs(hcDeviceMap) do

        -- Watches each stat for changing setpoint or room temperature
        luup.variable_watch("hcMonitor",hcSetPointServiceId,"CurrentSetpoint", statId); -- this works
        luup.variable_watch("hcMonitor",hcCurrentTempServiceId,"CurrentTemperature", statId); -- YES!

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
        hcDeviceMap[39]  = {900}
        -- Kitchen
        hcDeviceMap[800] = {901}
        -- Dining room
        hcDeviceMap[801] = {902}
        -- Lounge
        hcDeviceMap[36]  = {903,904}
        -- Office
        hcDeviceMap[28]  = {905}
        -- Master bedroom
        hcDeviceMap[802] = {905}
        -- Flo room
        hcDeviceMap[803] = {906}
        -- Spare room
        hcDeviceMap[804] = {907}
        -- Bathroom
        hcDeviceMap[805] = {908}
    end

    -- Test relay or default
    if(relayId ~= nil) then
        hcRelayId = relayId
    end

    hcInitDeviceMap()

    luup.log("hcStartup started monitoring at ".. os.date("%H:%M:%S"),25)
end
