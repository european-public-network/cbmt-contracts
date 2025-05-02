// scripts/setup-cbmt-banks-customers.js
"use strict";

const { ethers, upgrades } = require("hardhat");
const fs = require('fs-extra');
const dotenv = require('dotenv');

async function attachContract(name, address) {
  const factory = await ethers.getContractFactory(name);
  const GeneralCBMT_Contract_a = await( GeneralCBMT_Contract_f.attach("0xbAF54F48BCb750EF730f771a8AE5F7ee999CC5a7"));
  const GeneralCBMT_Contract = await( GeneralCBMT_Contract_a.connect(owner) );
  return await factory.attach(address);
}

async function loadJSONFile( filename ) {
    const buf = await fs.readFile(filename);
    return JSON.parse( buf )
}

async function loadConfigFile( filename ) {
    const buf = await fs.readFile(filename);
    return dotenv.parse( buf )
}

function loadEnvFile(filePath) {
  const fullPath = filePath;
  if (!fs.existsSync(fullPath)) {
    throw new Error(`File ${fullPath} does not exist`);
  }
  return dotenv.parse(fs.readFileSync(fullPath));
}

async function attachContracts(owner, envFilename) {
  let deploymentInfo = await loadConfigFile(envFilename);
  
  const GeneralCBMT_Contract = attachContract('GeneralCBMT', deploymentInfo.GENERAL_CONTRACT_ADDRESS );
  const CBMT_Contract = attachContract('CBMT', deploymentInfo.CBMT_CONTRACT_ADDRESS );
  
  return { GeneralCBMT_Contract, CBMT_Contract, Escrow_Contract: undefined }
}

function loadBankConfig( basename, visual ) {
    console.log( `Loading ${visual}` );
    const config = {
        "name" : visual,
        "issuing" : loadEnvFile(`credentials/.${basename}-issuing.env`),
        "mint" : loadEnvFile(`credentials/.${basename}-mint.env`),
        "redemption" : loadEnvFile(`credentials/.${basename}-redemption.env`),
        "ga" : loadEnvFile(`credentials/.${basename}-ga.env`),
    };

    for( let key of ["issuing", "mint", "redemption", "ga"]) {
        config[key].address = config[key].PUBLIC_KEY;
    }

  return config
}

function loadCustomerConfig( basename, visual ) {
    const config = {
        "name" : visual,
        "ga" : loadEnvFile(`credentials/.${basename}-ga.env`),
        "ca" : loadEnvFile(`credentials/.${basename}-ca.env`),
    };

    for( let key of ["ca", "ga"]) {
        config[key].address = config[key].PUBLIC_KEY;
    }

  return config
}

async function createBank( GeneralCBMT_Contract, owner, info ) {
    const bank_id = await GeneralCBMT_Contract.bank_Id();
    console.log(`[TSP] add ${info.name} to the consortium ${owner}`);
    const addParticipatingBank = await GeneralCBMT_Contract.connect( owner ).addParticipatingBank(
        info.issuing.address,
        info.mint.address,
        info.redemption.address,
        info.ga.address,
        info.name,
    );
    await addParticipatingBank.wait(1);
    const bank_info = await GeneralCBMT_Contract.getParticipatingBank(bank_id);
    await log(addParticipatingBank);
    console.log(`${info.name} done (${bank_id}): ${bank_info}`);

    return bank_id
}

// XXX this one should also respect PUBLIC_KEY and PRIVATE_KEY
//     Maybe this should be getSignerFromProfile() and should return a
//     Signer instead of a Wallet ...
async function getWallet(name, type) {
	const filename = `credentials/.${name}-${type}.env`;
	const buf = fs.readFileSync(filename);
	const conf = dotenv.parse(buf);
	const provider = hre.ethers.provider;

    let w;
    if( conf.PRIVATE_KEY ) {
        w = new ethers.Wallet( conf.PRIVATE_KEY );

    } else if( conf.MNEMONIC ) {
        w = new ethers.Wallet.fromMnemonic( conf.MNEMONIC );

    } else {
        console.log(conf);
        console.error(`Could not find a suitable key in ${filename}`);
        process.exit(-1);
    }

    return ((await w).connect(provider))
}

const supportedCurrencies = [978, 840];
const EUR_ID = supportedCurrencies[0];
const USD_ID = supportedCurrencies[1];

async function setupCBMTContracts( owner, GeneralCBMT_Contract, CBMT_Contract) {
  const unicreditConfig = loadBankConfig('unicredit', 'UniCredit');
  const dzbankConfig = loadBankConfig('dz', 'DZ BANK');
  const bank300Config = loadBankConfig('bank-300', 'BANK 300');
  const bank400Config = loadBankConfig('bank-400', 'BANK 400');
  const bankHelabaConfig = loadBankConfig('helaba', 'Helaba');
  const bankCommerzbankConfig = loadBankConfig('commerzbank', 'Commerzbank');

  const customer1Config = loadCustomerConfig('evonik', 'Evonik');
  const customer2Config = loadCustomerConfig('basf', 'BASF');
  const customer3Config = loadCustomerConfig('siemens', 'Siemens');

  const bank1Name = "UniCredit";
  const bank2Name = "DZ BANK";
  const bank3Name = "Bank 300";
  // CHG001
  const base_amount = 100000000;

  const blankAmount = 10000000 * base_amount;
  const amountToStamp = 5000000 * base_amount;
  const label = new Uint8Array("CBMT Test".split("").map( (c) => { return c.charCodeAt(0) } ));
  const EURtoUSDrate = 1060000;
  const USDtoEURrate = 940000;
  const amountRequested = 100000 * base_amount;

  const unicredit       = await createBank(GeneralCBMT_Contract, owner, unicreditConfig);
  const dzbank          = await createBank(GeneralCBMT_Contract, owner, dzbankConfig);
  console.log("Bank ID DZ Bank: %s", dzbank);
  const bank300         = await createBank(GeneralCBMT_Contract, owner, bank300Config);
  const bank400         = await createBank(GeneralCBMT_Contract, owner, bank400Config);
  const bankHelaba      = await createBank(GeneralCBMT_Contract, owner, bankHelabaConfig);
  const bankCommerzbank = await createBank(GeneralCBMT_Contract, owner, bankCommerzbankConfig);

  console.log("Bank DZ %s request 10,000,000 EUR %s in blank token",dzbank,EUR_ID);
  const requestBlankToken_EUR_A = await CBMT_Contract.connect( await getWallet('dz', 'issuing')).requestBlankToken( dzbank, EUR_ID, blankAmount );
  await requestBlankToken_EUR_A.wait();
  await log(requestBlankToken_EUR_A);

  console.log(``);

  //await sleep(3000);

  console.log("UniCredit request 10,000,000 EUR in blank token");
  const requestBlankToken_EUR_B = await CBMT_Contract.connect( await getWallet('unicredit', 'issuing')).requestBlankToken( unicredit, EUR_ID, blankAmount );
  await requestBlankToken_EUR_B.wait();
  await log(requestBlankToken_EUR_B);
  console.log(``);

  //await sleep(3000);

  console.log("Bank 300 request 10,000,000 EUR in blank token");
  const requestBlankToken_EUR_C = await CBMT_Contract.connect( await getWallet('bank-300', 'issuing')).requestBlankToken( bank300, EUR_ID, blankAmount );
  await requestBlankToken_EUR_C.wait();
  await log(requestBlankToken_EUR_C);
  console.log(``);

  //await sleep(3000);

  console.log(`DZ BANK stamp 5,000,000 EUR in token ${EUR_ID}`, );
  const stampToken_EUR_A = await CBMT_Contract.connect( await getWallet('dz', 'mint') ).stampToken( dzbank, EUR_ID, amountToStamp, label );
  await stampToken_EUR_A.wait();
  await log(stampToken_EUR_A);
  console.log(``);

  //await sleep(3000);

  console.log("Unicredit stamp 5,000,000 EUR in token");
  const stampToken_EUR_B = await CBMT_Contract.connect( await getWallet('unicredit', 'mint') ).stampToken( unicredit, EUR_ID, amountToStamp, label );
  await stampToken_EUR_B.wait();
  await log(stampToken_EUR_B);
  console.log(``);

  //await sleep(3000);

  console.log("Bank C stamp 5,000,000 EUR in token");
  const stampToken_EUR_C = await CBMT_Contract.connect( await getWallet('bank-300', 'mint') ).stampToken( bank300, EUR_ID, amountToStamp, label );
  await stampToken_EUR_C.wait();
  await log(stampToken_EUR_C);
  console.log(``);

  await sleep(3000);


  console.log("Bank DZ request USD 10,000,000 in blank token");
  const requestBlankToken_USD_A = await CBMT_Contract.connect( await getWallet('dz', 'issuing') ).requestBlankToken( dzbank, USD_ID, blankAmount );
  await requestBlankToken_USD_A.wait();
  await log(requestBlankToken_USD_A);
  console.log(``);

  await sleep(3000);

  console.log("Bank unicredit request 10,000,000 USD in blank token");
  const requestBlankToken_USD_B = await CBMT_Contract.connect( await getWallet('unicredit', 'issuing') ).requestBlankToken( unicredit, USD_ID, blankAmount );
  await requestBlankToken_USD_B.wait();
  await log(requestBlankToken_USD_B);
  console.log(``);

  await sleep(3000);


  console.log("Bank 3000 request 10,000,000 USD in blank token");
  const requestBlankToken_USD_C = await CBMT_Contract.connect( await getWallet('bank-300', 'issuing') ).requestBlankToken( bank300, USD_ID, blankAmount );
  await requestBlankToken_USD_C.wait();
  await log(requestBlankToken_USD_C);
  console.log(``);

  await sleep(3000);

  console.log("Bank DZ stamp 5,000,000 USD in token");
  const stampToken_USD_A = await CBMT_Contract.connect( await getWallet('dz', 'mint') ).stampToken( dzbank, USD_ID, amountToStamp, label );
  await stampToken_USD_A.wait();
  await log(stampToken_USD_A);
  console.log(``);

  await sleep(3000);

  console.log("Bank unicredit stamp 5,000,000 USD in token");
  const stampToken_USD_B = await CBMT_Contract.connect( await getWallet('unicredit', 'mint') ).stampToken( unicredit, USD_ID, amountToStamp, label );
  await stampToken_USD_B.wait();
  await log(stampToken_USD_B);
  console.log(``);

  await sleep(3000);

  console.log("Bank 3000 stamp 5,000,000 USD in token");
  const stampToken_USD_C = await CBMT_Contract.connect( await getWallet('bank-300', 'mint')).stampToken( bank300, USD_ID, amountToStamp, label );
  await stampToken_USD_C.wait();
  await log(stampToken_USD_C);
  console.log(``);

  await sleep(3000);

  console.log("Bank DZ set the exchange rate between EUR & USD pair");
  const setExchangeRateA_EURUSD = await CBMT_Contract.connect( await getWallet('dz', 'ga') ).setExchangeRate( dzbank, EUR_ID, USD_ID, EURtoUSDrate);
  await setExchangeRateA_EURUSD.wait();
  await log(setExchangeRateA_EURUSD);
  console.log(``);

  await sleep(3000);

  console.log("Bank DZ set the exchange rate between USD & EUR pair");
  const setExchangeRateA_USDEUR = await CBMT_Contract.connect( await getWallet('dz', 'ga') ).setExchangeRate( dzbank, USD_ID, EUR_ID, USDtoEURrate);
  await setExchangeRateA_USDEUR.wait();
  await log(setExchangeRateA_USDEUR);
  console.log(``);

  await sleep(3000);

  console.log("Bank unicredit set the exchange rate between EUR & USD pair");
  const setExchangeRateB_EURUSD = await CBMT_Contract.connect( await getWallet('unicredit', 'ga') ).setExchangeRate( unicredit, EUR_ID, USD_ID, EURtoUSDrate);
  await setExchangeRateB_EURUSD.wait();
  await log(setExchangeRateB_EURUSD);
  console.log(``);

  await sleep(3000);

  console.log("Bank unicredit set the exchange rate between USD & EUR pair");
  const setExchangeRateB_USDEUR = await CBMT_Contract.connect( await getWallet('unicredit', 'ga') ).setExchangeRate( unicredit, USD_ID, EUR_ID, USDtoEURrate);
  await setExchangeRateB_USDEUR.wait();
  await log(setExchangeRateB_USDEUR);

  await sleep(3000);

  console.log("Bank 3000 set the exchange rate between EUR & USD pair");
  const setExchangeRateC_EURUSD = await CBMT_Contract.connect( await getWallet('bank-300', 'ga') ).setExchangeRate( bank300, EUR_ID, USD_ID, EURtoUSDrate);
  await setExchangeRateC_EURUSD.wait();
  await log(setExchangeRateC_EURUSD);
  console.log(``);

  await sleep(3000);

  console.log("Bank 3000 set the exchange rate between USD & EUR pair");
  const setExchangeRateC_USDEUR = await CBMT_Contract.connect( await getWallet('bank-300', 'ga') ).setExchangeRate( bank300, USD_ID, EUR_ID, USDtoEURrate);
  await setExchangeRateC_USDEUR.wait();
  await log(setExchangeRateC_USDEUR);
  console.log(``);

  await sleep(3000);

  console.log(``);
  console.log(``);
  console.log("------------------------------------");
  console.log("CUSTOMERS SETUP");
  console.log("------------------------------------");
  console.log(``);
  console.log(``);

  console.log("Bank DZ whitelist Customer 1");
  const whitelistCustomer1FromBank_A = await GeneralCBMT_Contract.connect( await getWallet('dz', 'mint') ).addToWhitelist( dzbank, customer1Config.ga.address);
  await whitelistCustomer1FromBank_A.wait();
  await log(whitelistCustomer1FromBank_A);
  console.log(``);

  console.log("Customer 1 register to Bank DZ");
  const registerCustomer1ToBank_A= await GeneralCBMT_Contract.connect( await getWallet('evonik', 'ca') ).registerCustomer( dzbank, customer1Config.ga.address);
  await registerCustomer1ToBank_A.wait();
  await log(registerCustomer1ToBank_A);
  console.log(``);

  console.log("Bank DZ adds EUR currency to Customer 1");
  const addCurrencyToCustomer1FromBank_A = await GeneralCBMT_Contract.connect( await getWallet('dz', 'mint') ).addCurrencyToCustomer( dzbank, customer1Config.ca.address, [ EUR_ID ]);
  await addCurrencyToCustomer1FromBank_A.wait();
  await log(addCurrencyToCustomer1FromBank_A);
  console.log(``);

  console.log("Bank DZ whitelist Customer 2");
  const whitelistCustomer2FromBank_A = await GeneralCBMT_Contract.connect( await getWallet('dz', 'mint') ).addToWhitelist( dzbank, customer2Config.ga.address);
  await whitelistCustomer2FromBank_A.wait();
  await log(whitelistCustomer2FromBank_A);
  console.log(``);

  console.log("Customer 2 register to Bank DZ");
  const registerCustomer2ToBank_A= await GeneralCBMT_Contract.connect( await getWallet('basf', 'ca') ).registerCustomer( dzbank, customer2Config.ga.address);
  await registerCustomer2ToBank_A.wait();
  await log(registerCustomer2ToBank_A);
  console.log(``);

  console.log("Bank DZ adds EUR currency to Customer 2");
  const addCurrencyToCustomer2FromBank_A= await GeneralCBMT_Contract.connect( await getWallet('dz', 'mint') ).addCurrencyToCustomer( dzbank, customer2Config.ca.address, [ EUR_ID ]);
  await addCurrencyToCustomer2FromBank_A.wait();
  await log(addCurrencyToCustomer2FromBank_A);
  console.log(``);

  console.log("Bank unicredit whitelist Customer 3");
  const whitelistCustomer3FromBank_B = await GeneralCBMT_Contract.connect( await getWallet('unicredit', 'mint') ).addToWhitelist( unicredit, customer3Config.ga.address);
  await whitelistCustomer3FromBank_B.wait();
  await log(whitelistCustomer3FromBank_B);
  console.log(``);

  console.log("Customer 3 register to Bank unicredit");
  const registerCustomer3ToBank_B = await GeneralCBMT_Contract.connect( await getWallet('siemens', 'ca') ).registerCustomer( unicredit, customer3Config.ga.address);
  await registerCustomer3ToBank_B.wait();
  await log(registerCustomer3ToBank_B);
  console.log(``);

  console.log("Bank unicredit adds EUR currencies to Customer 3");
  const addCurrencyToCustomer3FromBank_B = await GeneralCBMT_Contract.connect( await getWallet('unicredit', 'mint') ).addCurrencyToCustomer( unicredit, customer3Config.ca.address, [ EUR_ID ]);
  await addCurrencyToCustomer3FromBank_B.wait();
  await log(addCurrencyToCustomer3FromBank_B);
  console.log(``);

/*
  console.log("Bank DZ whitelist Customer 4");
  const whitelistCustomer4FromBank_A = await GeneralCBMT_Contract.connect( await getWallet('dz', 'mint') ).addToWhitelist( dzbank, customer4Config.ga.address);
  await whitelistCustomer4FromBank_A.wait();
  await log(whitelistCustomer4FromBank_A);
  console.log(``);

  await sleep(3000);

  console.log("Customer 4 register to Bank DZ");
  const registerCustomer4ToBank_A= await GeneralCBMT_Contract.connect( customer4Config.ca.address ).registerCustomer( dzbank, customer4Config.ga.address);
  await registerCustomer4ToBank_A.wait();
  await log(registerCustomer4ToBank_A);
  console.log(``);

  await sleep(3000);

  console.log("Bank DZ adds USD currency to Customer 4");
  const addCurrencyToCustomer4FromBank_A = await GeneralCBMT_Contract.connect( bank1Mint ).addCurrencyToCustomer( bank_1_id, customer4Convert.address, [ USD_ID ]);
  await addCurrencyToCustomer4FromBank_A.wait();
  await log(addCurrencyToCustomer4FromBank_A);
  console.log(``);

  await sleep(3000);

  console.log("Bank DZ removes EUR currency from Customer 4");
  const removeCurrencyFrom4 = await GeneralCBMT_Contract.connect( bank1Mint ).removeCurrencyFromCustomer( bank_1_id, customer4Convert.address, EUR_ID );
  await removeCurrencyFrom4.wait();
  await log(removeCurrencyFrom4);
  console.log(``);

  await sleep(3000);

  console.log("Customer 3 request 100,000 EUR in token to Bank B");
  const customer3RequestEURToken_ToBank_B = await CBMT_Contract.connect( bank2Mint ).requestTokenFromCustomer( bank_2_id, customer3General.address, EUR_ID, amountRequested );
  await customer3RequestEURToken_ToBank_B.wait();
  await log(customer3RequestEURToken_ToBank_B);

  await sleep(3000);

  console.log(``);
  console.log(``);
  console.log("------------------------------------");
  console.log("Escrow SETUP");
  console.log("------------------------------------");
  console.log(``);
  console.log(``);

  console.log("Bank DZ whitelists EscrowCBMT contract address");
  const whitelistEscrowFromBank_A = await GeneralCBMT_Contract.connect( bank1Mint ).addToWhitelist( bank_1_id, EscrowCBMT_Contract.address );
  await whitelistEscrowFromBank_A.wait();
  await log(whitelistEscrowFromBank_A);
  console.log(``);
*/
  console.log(``);
  console.log("Script executed successfully ✔");
}

async function main() {
  process.env.NODE_TLS_REJECT_UNAUTHORIZED=0;
  const env = process.env.ENV || 'test';
  const envFilename = `.cbmt-contracts-${env}.env`;

  const provider = hre.ethers.provider;
  const [ owner ] = await ethers.getSigners();

  const network = await provider.getNetwork();
  console.log("Chain ID",network.chainId);
  console.log("Network name",network.name);
  console.log("Ethers version",ethers.version);
  console.log("gasprice",await provider.getFeeData());
  console.log("Owner address:", owner.address);

  const amount = parseFloat(ethers.formatEther(await hre.ethers.provider.getBalance(owner.address)),10);
  console.log(`• ${owner.address} EVE balance: ${amount.toFixed(8)} (EVE)`);
  
  const { GeneralCBMT_Contract, CBMT_Contract, Escrow_Contract } = await attachContracts( owner, envFilename );
  await setupCBMTContracts( owner, GeneralCBMT_Contract, CBMT_Contract );

}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function log(tx) {
  const base = process.env["CBMT_EXPLORER_URL"] || "https://explorer.evan.network/";
  const message = `${base}tx/${tx.hash}`;

  console.log("You can see the tx status:" + message);

  try {
    await fs.appendFile('transaction-hash.txt', message + '\n');
  } catch (err) {
    console.error('Error writing to file', err);
  }
}

main();