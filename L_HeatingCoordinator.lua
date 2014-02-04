local totalDevices = 0
local coordinatorServiceId = 'urn:dmlogic-com:serviceId:HeatingCoordinator1'
local setPointServiceId    = 'urn:upnp-org:serviceId:TemperatureSetpoint1_Heat'
local currentTempServiceId = 'urn:upnp-org:serviceId:TemperatureSensor1'
local relayServiceId       = 'urn:upnp-org:serviceId:HVAC_UserOperatingMode1'
local tooSoon = 120 -- every 2 mins is just fines

--[[
  Splits up the supplied string into a table
  of device IDs
]]--
function hc_extractIds(inputstr, sep)

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

function hc_deviceNeedsHeat(deviceId)

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

function hc_setRelay(setValue,relayId)

    -- note when last set
    hc_logLastSet(relayId)

    args = {}
    args.NewModeTarget = setValue

    -- set the relay
    -- http://192.168.1.104:3480/data_request?id=action&DeviceNum=42&serviceId=urn:upnp-org:serviceId:HVAC_UserOperatingMode1&action=SetModeTarget&NewModeTarget=Off
    -- http://192.168.1.104:3480/data_request?id=variableget&DeviceNum=42&Variable=ModeStatus&serviceId=urn:upnp-org:serviceId:HVAC_UserOperatingMode1
    return luup.call_action(relayServiceId,'SetModeTarget',args,relayId)

end

function hc_tooSoon(relayId)

    last = luup.variable_get(coordinatorServiceId,'lastRelaySetTime',relayId)

    if(last == nil) then
        hc_logLastSet(relayId)
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

function hc_logLastSet(relayId,t)
    setTime = time or os.time()
    luup.variable_set(coordinatorServiceId,'lastRelaySetTime',setTime,relayId)
end

--[[
  Do your thang
]]--
function hc_Process(deviceIds,relayId)

    if(hc_tooSoon(relayId) == true) then
        return 'too soon'
    end

    -- figure out which devices we are looking at
    deviceTable = hc_extractIds(deviceIds,',')

    if(totalDevices == 0) then
        return
    end

    for k,v in pairs(deviceTable) do
        if(hc_deviceNeedsHeat(v) == true) then
            hc_setRelay('HeatOn',relayId)
            return k
        end
    end

    hc_setRelay('Off',relayId)

    return totalDevices

end

function hc_Startup(lul_device)
    luup.task("Running Lua Startup", 1, "HeatingCoordinator", -1)

    coordinatorId = lul_device
end