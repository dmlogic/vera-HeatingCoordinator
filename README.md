I'm becoming more and more certain we need to be looking at:

Z-Wave Group 2
serviceId=urn:upnp-org:serviceId:SwitchPower1
action=SetTarget
newTargetValue=

Variables from stats:
http://192.168.1.104:3480/data_request?id=variableget&DeviceNum=39&serviceId=urn:upnp-org:serviceId:TemperatureSetpoint1_Heat&Variable=SetpointTarget

http://192.168.1.104:3480/data_request?id=variableget&DeviceNum=39&serviceId=urn:upnp-org:serviceId:TemperatureSensor1&Variable=CurrentTemperature

Variable on relay:
serviceId=urn:upnp-org:serviceId:HVAC_UserOperatingMode1
ModeStatus: HeatOn|Off