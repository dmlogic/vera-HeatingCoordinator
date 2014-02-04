--[[
    Emulates the lua luup extensions for testing
]]
luup = {}
local luupvars = {}

function luup.task(a,b,c,d)
    taskMessage = a
end

function luup.variable_get(serviceId,varName,deviceId)
    key = serviceId..varName..deviceId
    -- print("variable get: "..key)
    return luupvars[key]
end

function luup.variable_set(serviceId,varName,value,deviceId)
    key = serviceId..varName..deviceId
    luupvars[key] = value

    -- print("variable set: "..key..":"..value)
end

function luup.call_action(serviceId,actionName,args,deviceId)

    for k,v in pairs(args) do
        -- print("pairs "..serviceId..","..k..","..v..","..deviceId)
        luup.variable_set(serviceId,k,v,deviceId)
    end

    -- this allows us to test at least that the call was made as expected
    return {serviceId,actionName,args,deviceId}
end