function dmHeatingMonitor(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)

    luup.log("DMHeating lul_device:"..lul_device..", lul_variable:"..lul_variable..", lul_value_old:"..lul_value_old..", lul_value_new at "..local mydate = os.date("%H:%M:%S"),25)
end

luup.variable_watch("dmHeatingMonitor","urn:upnp-org:serviceId:TemperatureSetpoint1_Heat","CurrentSetpoint", 28);
luup.variable_watch("dmHeatingMonitor","rn:upnp-org:serviceId:TemperatureSensor1","CurrentTemperature", 28);

 luup.log("DMHeating started monitoring at "..local mydate = os.date("%H:%M:%S"),25)