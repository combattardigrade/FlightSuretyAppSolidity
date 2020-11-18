import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
require("regenerator-runtime/runtime");

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);


const start = async () => {
  const oracles = []
  const accounts = await web3.eth.getAccounts()

  flightSuretyApp.events.OracleRequest()
    .on('error', error => { console.log(error) })
    .on('data', async (data) => {

      const airline = data.returnValues.airline
      const flight = data.returnValues.flight
      const timestamp = data.returnValues.timestamp
      console.log(`flight: ${flight}, airline: ${airline}, time: ${timestamp}`)
      

      for (let oracle of oracles) {
        const oracleIndexes = await flightSuretyApp.methods.getMyIndexes().call({
          from: oracle,
          gasPrice: '100000000000',
          gasLimit: '2500000'
        })

        for (let index of oracleIndexes) {
          const statusCode = Math.floor(Math.random() * Math.floor(5)) * 10
          try {
            await flightSuretyApp.methods.submitOracleResponse(
              index,
              airline,
              flight,
              timestamp,
              statusCode
            ).send({
              from: oracle,
              gasPrice: '100000000000',
              gasLimit: '2500000'
            })

          } catch (e) {
            console.log(e)
          }
        }
      }
    })

  for (let account of accounts.slice()) {
    try {
      await flightSuretyApp.methods.registerOracle().send({
        from: account,
        value: web3.utils.toWei('10', 'ether'),
        gasPrice: '100000000000',
        gasLimit: '2500000'
      })

      oracles.push(account)

    } catch (e) {
      console.log(e)
    }
  }

}

start()



const app = express();
app.get('/api', (req, res) => {
  res.send({
    message: 'An API for use with your Dapp!'
  })
})

export default app;


