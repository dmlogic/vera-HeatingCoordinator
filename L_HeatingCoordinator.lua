local totalDevices = 0
local coordinatorServiceId = 'urn:dmlogic-com:serviceId:HeatingCoordinator1'
local setPointServiceId    = 'urn:upnp-org:serviceId:TemperatureSetpoint1_Heat'
local currentTempServiceId = 'urn:upnp-org:serviceId:TemperatureSensor1'
local relayServiceId       = 'urn:upnp-org:serviceId:HVAC_UserOperatingMode1'
local tooSoon = 120 -- every 2 mins is just fine

--[[
  Splits up the supplied string into a table
  of device IDs
--]]
function hcextractIds(inputstr, sep)

    totalDevices = 0

    if sep == nil then
        sep = "%s"
    end

    t={} ; i=1

    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = tonumber(str)
        i = i + 1
        totalDevices = totalDevices + 1
    end

    return t
end

function hcdeviceNeedsHeat(deviceId)

    local setPoint = luup.variable_get(setPointServiceId,'SetpointTarget', deviceId)
    local current  = luup.variable_get(currentTempServiceId,'CurrentTemperature', deviceId)

    if (setPoint == nil or  current == nil) then
        return false
    end

    if(current < setPoint) then
        return true
    end

    return false
end

function hcsetRelay(setValue,relayId)

    -- note when last set
    hclogLastSet(relayId)

    args = {}
    args.NewModeTarget = setValue

    -- set the relay
    -- http://192.168.1.104:3480/data_request?id=action&DeviceNum=42&serviceId=urn:upnp-org:serviceId:HVAC_UserOperatingMode1&action=SetModeTarget&NewModeTarget=Off
    -- http://192.168.1.104:3480/data_request?id=variableget&DeviceNum=42&Variable=ModeStatus&serviceId=urn:upnp-org:serviceId:HVAC_UserOperatingMode1
    return luup.call_action(relayServiceId,'SetModeTarget',args,relayId)

end

function hctooSoon(relayId)

    last = luup.variable_get(coordinatorServiceId,'lastRelaySetTime',relayId)

    if(last == nil) then
        hclogLastSet(relayId)
        return false
    end

    now = os.time()
    diff = now - last

    if(diff < tooSoon) then
        return false
    else
        return true
    end
end

function hclogLastSet(relayId,t)
    setTime = time or os.time()
    luup.variable_set(coordinatorServiceId,'lastRelaySetTime',setTime,relayId)
end

--[[
  Do your thang
]]--
function hcProcess(lul_device, lul_settings)
    luup.log("hcProcess",25)
    if(hctooSoon(relayId) == true) then
        return 'too soon'
    end

    -- figure out which devices we are looking at
    deviceTable = hcextractIds(deviceIds,',')

    if(totalDevices == 0) then
        return
    end

    for k,v in pairs(deviceTable) do
        if(hcdeviceNeedsHeat(v) == true) then
            hcsetRelay('HeatOn',relayId)
            return k
        end
    end

    hcsetRelay('Off',relayId)

    return totalDevices

end

function hcMonitor(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)

    luup.log("DMHeating lul_device:"..lul_device..", lul_variable:"..lul_variable..", lul_value_old:"..lul_value_old..", lul_value_new:"..lul_value_new.." at ".. os.date("%H:%M:%S"),25)
end

function hcStartup(lul_device)

    luup.task("Running Lua Startup", 1, "HeatingCoordinator", -1)

    --coordinatorId = lul_device

    luup.variable_watch("hcMonitor","urn:upnp-org:serviceId:TemperatureSetpoint1_Heat","CurrentSetpoint", 28); -- this works
    luup.variable_watch("hcMonitor","urn:upnp-org:serviceId:TemperatureSensor1","CurrentTemperature", 28); -- YES!

    luup.log("hcStartup started monitoring at ".. os.date("%H:%M:%S"),25)
end
