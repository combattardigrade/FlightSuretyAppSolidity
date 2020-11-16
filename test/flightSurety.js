
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeAccount(config.flightSuretyApp.address);
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false);
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSurety.setTestingMode(true);
        }
        catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

    });

    it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

        // ARRANGE
        let newAirline = accounts[2];

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(newAirline, { from: accounts[2] });
        }
        catch (e) {

        }

        let result = await config.flightSuretyData.getAirline.call(newAirline);

        // ASSERT
        assert.equal(result[0], false, "Airline should not be able to register another airline if it hasn't provided funding");

    });

    it('(airline) can register new airline until there are at least four airlines registered', async () => {
        for (let i = 1; i < 5; i++) {
            try {
                await config.flightSuretyApp.registerAirline(accounts[i], { from: accounts[0] });
            } catch (e) {

            }
        }
        let result1 = await config.flightSuretyData.getAirline.call(accounts[1])
        let result2 = await config.flightSuretyData.getAirline.call(accounts[5])

        assert.equal(result1[0], true, "Airline no. 1 should be created")
        assert.equal(result2[0], false, "Airline no. 5 should not be created")
    })

    it('Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines', async () => {

        for (let i = 1; i < 5; i++) {
            try {                
                await config.flightSuretyApp.payRegistrationFee(accounts[i], { from: accounts[i], value: '10000000000000000000' })
            } catch (e) {
                
            }
        }        

        for (let i = 0; i < 5; i++) {
            try {
                await config.flightSuretyApp.registerAirline(accounts[6], { from: accounts[i] });
            } catch (e) {
                console.log(e)
            }
        }

        let result1 = await config.flightSuretyData.getAirline.call(accounts[6])        
        assert.equal(result1[0], true, "Airline no. 5 should be created with multi-party consensus")
    })

});
