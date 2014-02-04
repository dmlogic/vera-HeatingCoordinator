require('luaunit')

package.path = '../?.lua;'..package.path
require('luup');
require('L_HeatingCoordinator')

local testCoordinatorServiceId = 'urn:dmlogic-com:serviceId:HeatingCoordinator1'
local testSetPointServiceId    = 'urn:upnp-org:serviceId:TemperatureSetpoint1_Heat'
local testCurrentTempServiceId = 'urn:upnp-org:serviceId:TemperatureSensor1'
local testRelayServiceId       = 'urn:upnp-org:serviceId:HVAC_UserOperatingMode1'

TestCode = {} --class

    function TestCode:testStartUp()
        hc_Startup('abc')
    end

    --[[
        Make sure we'll get our stat IDs properlys
    ]]
    function TestCode:testExtractIds()

        ids = '123,456,abc,789'
        result = hc_extractIds(ids,',')

        assertEquals(type(result),'table')
        assertEquals(result[1],123)
        assertEquals(result[3],nil)
    end

    --[[
        Test the call for heat lookup
    ]]
    function TestCode:testDeviceNeedsHeat()

        luup.variable_set(testCurrentTempServiceId,'CurrentTemperature',5,1)
        luup.variable_set(testSetPointServiceId,'SetpointTarget',10,1)

        res = hc_deviceNeedsHeat(1)
        assertEquals(res,true)

        luup.variable_set(testCurrentTempServiceId,'CurrentTemperature',25,2)
        luup.variable_set(testSetPointServiceId,'SetpointTarget',20,2)

        res = hc_deviceNeedsHeat(2)
        assertEquals(res,false)
    end

    function TestCode:testSetRelay()

        before = os.time()

        -- check the action follows through with correct arguments
        res = hc_setRelay('Off',100)
        assertEquals(type(res),'table');
        assertEquals(res[2],'SetModeTarget');
        args = res[3]
        assertEquals(type(args),'table');
        assertEquals(args.NewModeTarget,'Off');

        -- check that the last set time is updated
        last = luup.variable_get(testCoordinatorServiceId,'lastRelaySetTime', 100)
        assertEquals((before <= last),true)
    end

    --[[
        Now pull everything together
    ]]
    function TestCode:testTurnOn()

        -- reset the time
        hc_logLastSet(100,os.time() - 200)

        -- three stats, two need heat
        stats = '1,2,3'
        luup.variable_set(testCurrentTempServiceId,'CurrentTemperature',22,1)
        luup.variable_set(testSetPointServiceId,'SetpointTarget',18,1)
        luup.variable_set(testCurrentTempServiceId,'CurrentTemperature',18,2)
        luup.variable_set(testSetPointServiceId,'SetpointTarget',20,2)
        luup.variable_set(testCurrentTempServiceId,'CurrentTemperature',5,3)
        luup.variable_set(testSetPointServiceId,'SetpointTarget',10,3)

        count = hc_Process(stats,100)

        -- should have bailed on second loop
        assertEquals(count,2)

        res = luup.variable_get(testRelayServiceId,'NewModeTarget', 100)

        assertEquals(res,'HeatOn')
    end

    function TestCode:testTurnOff( )

        -- two stats, both hot
        stats = '1,2'
        luup.variable_set(testCurrentTempServiceId,'CurrentTemperature',22,1)
        luup.variable_set(testSetPointServiceId,'SetpointTarget',18,1)
        luup.variable_set(testCurrentTempServiceId,'CurrentTemperature',25,2)
        luup.variable_set(testSetPointServiceId,'SetpointTarget',5,2)

        count = hc_Process(stats,100)

        -- should have looped everything
        assertEquals(count,2)

        res = luup.variable_get(testRelayServiceId,'NewModeTarget', 100)

        assertEquals(res,'Off')
    end
-- class TestCode

LuaUnit:run()