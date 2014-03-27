require('luaunit')

package.path = '../?.lua;'..package.path
require('luup');
require('L_HeatingCoordinator')

local testCoordinatorServiceId = 'urn:dmlogic-com:serviceId:HeatingCoordinator1'
local testSetPointServiceId    = 'urn:upnp-org:serviceId:TemperatureSetpoint1_Heat'
local testCurrentTempServiceId = 'urn:upnp-org:serviceId:TemperatureSensor1'
local testRelayServiceId       = 'urn:upnp-org:serviceId:HVAC_UserOperatingMode1'

local myMap = {}
myMap[1] = {2}
myMap[22] = {3,4,5}

TestCode = {} --class

    function TestCode:testStartUp()
        hcStartup(myMap)
        assertEquals(hcGetDeviceMap(),myMap);
    end

    function TestCode:testSetValveSetPoint()

        hcSetValveSetPoint({10,20,30},25);

        assertEquals(luup.variable_get('urn:upnp-org:serviceId:TemperatureSetpoint1_Heat',"NewCurrentSetpoint",10),25)
        assertEquals(luup.variable_get('urn:upnp-org:serviceId:TemperatureSetpoint1_Heat',"NewCurrentSetpoint",20),25)
        assertEquals(luup.variable_get('urn:upnp-org:serviceId:TemperatureSetpoint1_Heat',"NewCurrentSetpoint",30),25)
    end

    function TestCode:testSetRelay()

        before = os.time()

        -- check the action follows through with correct arguments
        res = hcSetRelay('Off',100)
        assertEquals(type(res),'table');
        assertEquals(res[2],'SetModeTarget');
        args = res[3]
        assertEquals(type(args),'table');
        assertEquals(args.NewModeTarget,'Off');

        -- check that the last set time is updated
        last = luup.variable_get(testCoordinatorServiceId,'lastRelaySetTime', 100)
        assertEquals((before <= last),true)
    end

    function TestCode:testTooSoonTimer()

        hcLogLastSet(100,os.time()-100)
        assertEquals(true,hcTooSoon(100))

        hcLogLastSet(100,os.time() - 200)
        assertEquals(false,hcTooSoon(100))

    end

    function TestCode:testDeviceNeedsHeat()

        luup.variable_set(testCurrentTempServiceId,'CurrentTemperature',5,1)
        luup.variable_set(testSetPointServiceId,'CurrentSetpoint',10,1)

        res = hcDeviceNeedsHeat(1)
        assertEquals(res,true)

        luup.variable_set(testCurrentTempServiceId,'CurrentTemperature',25,2)
        luup.variable_set(testSetPointServiceId,'CurrentSetpoint',20,2)

        res = hcDeviceNeedsHeat(2)
        assertEquals(res,false)
    end

    function TestCode:testProcessOn()

        hcStartup(myMap)

        -- reset the time
        hcLogLastSet(66,os.time() - 300)

        luup.variable_set(testCurrentTempServiceId,'CurrentTemperature',22,1)
        luup.variable_set(testSetPointServiceId,'CurrentSetpoint',25,1)

        res = hcProcess(66)

        -- should have bailed on second loop
        assertEquals(res,'heatOn')
    end

    function TestCode:testProcessOff( )

        -- reset the time
        hcLogLastSet(100,os.time() - 300)

        luup.variable_set(testCurrentTempServiceId,'CurrentTemperature',22,1)
        luup.variable_set(testSetPointServiceId,'CurrentSetpoint',18,1)

        res = hcProcess(100)

        -- should have bailed on second loop
        assertEquals(res,'heatOff')
    end

    function TestCode:testProcessTooSoon( ... )
        res = hcProcess(100)
        assertEquals(res,'tooSoon')
    end


-- class TestCode

LuaUnit:run()