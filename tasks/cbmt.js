"use strict";

import("@nomicfoundation/hardhat-toolbox"); // for the task() and scope() helper
const cfg = require("hardhat/config");
const dotenv = require('dotenv');
const fs = require('fs-extra');
const e = require('ethers');
const util = require('util')

// add to hardhat.config.js
// import( "./tasks/cbmt.js" );

// CHG001 const base_amount = 1000000;
const base_amount = 100000000;
// CHG002
const supportedCurrencies = [978, 840]; // EUR, USD
const currencyNames = {978 : 'EUR', 840 : 'USD'};

// Solidity / Ethers v6 want text as Uint8Array
function textToUint8( str ) {
    return new Uint8Array(str.split("").map( (c) => { return c.charCodeAt(0) } ));
}

async function cbmt_gas({ receiver, amount }, hre, runSuper) {
  const GeneralCBMT_Address = process.env.GENERAL_CBMT_EPN || process.env.GENERAL_CONTRACT_ADDRESS;
  const CBMT_Address = process.env.CBMT_EPN || process.env.CBMT_CONTRACT_ADDRESS;
  const receiverAddress = hre.ethers.getAddress(receiver);
  const owner = await getSigner(hre);
    let tx = {
      to: receiverAddress,
      // Convert currency unit from ether to wei
      value: ethers.parseEther(amount)
    };
    return await owner.sendTransaction(tx)
    .then((txObj) => {
      console.log(`Funded ${receiver} with ${amount} gas`)
    })
}

// XXX this one should also respect PUBLIC_KEY and PRIVATE_KEY
//     Maybe this should be getSignerFromProfile() and should return a
//     Signer instead of a Wallet ...
async function getWallet(type) {
	let name = process.env.ENVNAME;
    name = name.replace(/(.*)-\w+/, '$1');
	const filename = `./credentials/.${name}-${type}.env`;
	const buf = await fs.readFile(filename);
	const conf = dotenv.parse(buf);

    if( conf.PRIVATE_KEY ) {
        return new ethers.Wallet( conf.PRIVATE_KEY );

    } else if( conf.MNEMONIC ) {
        return new ethers.Wallet.fromMnemonic( conf.MNEMONIC );

    } else {
        console.log(conf);
        console.error(`Could not find a suitable key in ${filename}`);
        process.exit(-1);
    }
}

async function getCBMTGeneral(hre, user=undefined) {
    const GeneralCBMT_Address = process.env.GENERAL_CBMT_EPN || process.env.GENERAL_CONTRACT_ADDRESS;
    
    const GeneralCBMT = await hre.ethers.getContractFactory("GeneralCBMT");
    const GeneralCBMT_Contract = await GeneralCBMT.attach(GeneralCBMT_Address);

    const owner = user || (await getSigner(hre));
    const cbmt = GeneralCBMT_Contract.connect(owner);

    return cbmt
}

async function getCBMT(hre, user=undefined) {
    const CBMT_Address = process.env.CBMT_EPN || process.env.CBMT_CONTRACT_ADDRESS;

    const CBMT = await hre.ethers.getContractFactory("CBMT");
    const CBMT_Contract = await CBMT.attach(CBMT_Address);

    const owner = user || (await getSigner(hre));
    const cbmt = CBMT_Contract.connect(owner);

    return cbmt
}

// Dump all the old / pre-existing addresses
async function cbmt_addresses({}, hre, runSuper) {
    const [ owner, bank1Issuing, bank1Mint, bank1Redemption, bank1General, bank2Issuing, bank2Mint, bank2Redemption, bank2General, customer1General,
      customer1Convert, customer2General, customer2Convert, customer3General, customer3Convert ] = await ethers.getSigners();

/*
    const addresses = [ owner.address, bank1Issuing.address, bank1Mint.address, bank1General.address, bank2Issuing.address, bank2Mint.address,
      bank2General.address, customer1General.address, customer1Convert.address, customer2General.address, customer2Convert.address, customer3General.address,
      customer3Convert.address ];
*/
    // Dump the private keys too:
    const { Wallet } = require('ethers');

    let idx = 0;
    let addr = owner.address;

    for( idx of [0,1,2,3,4,5] ) {
        const derivationPath = `m/44'/60'/0'/0/${(idx)}`;
        //const wallet = Wallet.fromMnemonic(process.env.MNEMONIC, derivationPath);
        let provider = ethers.getDefaultProvider();
        const wallet = new Wallet(process.env.PRIVATE_KEY, provider, derivationPath);
        const pk = wallet.privateKey;
        console.log(`${addr}        ${derivationPath}    ${pk}`);

        idx++;
    }
}

/*

    const signer = await getSigner(hre, some_address);
    const signer = await getSigner(hre);

This creates a signer for the current session. The signer credentials are
determined as follows:

  1) env.PRIVATE_KEY if some_address == env.PUBLIC_KEY or some_address is not given
  2) env.PRIVATE_KEY_GENERAL is available, use that
  3) env.MNEMONIC

XXX This function should be split into getSignerFromConf(hre, address, conf) so
we can use it with process.env and other configurations

*/

async function getSigner(hre, address=process.env.PUBLIC_KEY) {
    let owner;

    // If we have a private key given, create a signer from that:
    if( process.env.PRIVATE_KEY && address == process.env.PUBLIC_KEY) {
        // console.log( `Setting up Wallet for ${address} from private key` );
        owner = new ethers.Wallet(process.env.PRIVATE_KEY, hre.ethers.provider);

    // Check if the address is one of the pre-existing addresses and properly find the signer from that
    } else if( address ) {
        // console.log( `Scanning for ${address}` );
        for( signer of await ethers.getSigners()) {
            console.log( `${signer.address} <=> ${address}` );
            if( signer.address == address ) {
                owner = signer;
                break;
            }
        }

    // If we have a backend-like config, use that:
    } else if( process.env.PRIVATE_KEY_GENERAL ) {
        owner = new ethers.Wallet(process.env.PRIVATE_KEY_GENERAL, hre.ethers.provider);

    } else {
        owner = (await hre.ethers.getSigners())[0]
    }
    return owner
}

async function cbmt_balance({ account, tokenid }, hre, runSuper) {
    const cbmt = await getCBMT(hre);
    const cbmtGeneral = await getCBMTGeneral(hre);

    if( ! account ) {
        account = (await getSigner(hre)).address;
    }

    if( tokenid === undefined ) {

        const tokenIds = [];

        // Iterate over the issuers and the currencies:
        let maxBank = Number(await cbmtGeneral.getCurrentBankId());
        
        let issuer = 0;
        while( issuer < maxBank) {
            for( let currency of supportedCurrencies ) { // EUR, USD
                tokenIds.push(issuer+currency);
            }
            // CHG002
            issuer += 1000;
        }

        // We could do a batch request here instead, using .balanceOfBatch(tokenIds)
        for( let token_id of tokenIds ) {
            await cbmt_balance({ account:account, tokenid:token_id }, hre);
        }

        const amount = parseFloat(ethers.formatEther(await hre.ethers.provider.getBalance(account)),10);
        console.log(`• ${account} EVA balance: ${amount.toFixed(8)} (EVA)`);

    } else {
        const balance = (Number(await cbmt.balanceOf(account, tokenid))/ base_amount ).toFixed(8);

        console.log(`• ${account} balance: ${balance} (tokenid = ${tokenid})`);
    }
}

async function cbmt_whitelist({ customer }, hre, runSuper) {
  const cbmtGeneral = getCBMTGeneral(hre);

  // Find "this" bank
  const bank_info = thisBank(hre, cbmtGeneral);
  if( ! bank_info) {
      console.log(`Could not find a bank owning ${bank.address}`);
      process.exit(-1);
  };
  const bank_id = bank_info._bankId;
  const whitelistCustomer1FromBank = await cbmtGeneral.connect( bank ).addToWhitelist( bank_id, customer );
  console.log(`Whitelisted ${customer} for bank ${bank_id}`);
}

async function cbmt_add_bank({ issuing, mint, redemption, general, name }, hre, runSuper) {
  const [owner] = await hre.ethers.getSigners(); // use our own credentials
  const GeneralCBMT_Address = process.env.GENERAL_CBMT_EPN || process.env.GENERAL_CONTRACT_ADDRESS;
  const CBMT_Address = process.env.CBMT_EPN || process.env.CBMT_CONTRACT_ADDRESS;

  const GeneralCBMT = await hre.ethers.getContractFactory("GeneralCBMT");
  const GeneralCBMT_Contract = await GeneralCBMT.attach(GeneralCBMT_Address);

  const CBMT = await hre.ethers.getContractFactory("CBMT");
  const CBMT_Contract = await CBMT.attach(CBMT_Address);

  // Here is a race condition, but addParticipatingBank doesn't return the fresh bank id
  const bank_id = await GeneralCBMT_Contract.getCurrentBankId();
  const addParticipatingBank = await GeneralCBMT_Contract.connect( owner ).addParticipatingBank(issuing, mint, redemption, general, name);

  // output the information on the newly created bank
  const info = await GeneralCBMT_Contract.getParticipatingBank(bank_id);
  return cbmt_print_bankinfo(info, hre, runSuper );
}

// Add a currency to a customer
//  console.log("Bank A adds EUR currencies to Customer 1");
//  const addCurrencyToCustomer1FromBank_A = await GeneralCBMT_Contract.connect( bank1Mint ).addCurrencyToCustomer( bank_1_id, customer1Convert.address, [ EUR_ID ]);
//  await addCurrencyToCustomer1FromBank_A.wait(3);
//  await log(addCurrencyToCustomer1FromBank_A);
//  console.log(``);

// Add a convert address
// console.log("Customer 2 register to Bank B");
// const registerCustomer2ToBank_B= await GeneralCBMT_Contract.connect( customer2Convert ).registerCustomer( bank_2_id, customer2General.address);
// await registerCustomer2ToBank_B.wait(3);
// await log(registerCustomer2ToBank_B);
// console.log(``);

function cbmt_print_bankinfo(bankinfo) {
  console.log(`${bankinfo._bankId};${bankinfo._issuingAddress};${bankinfo._mintAddress};${bankinfo._redemptionAddress};${bankinfo._generalAddress};${bankinfo._name}`);
}

async function cbmt_bankinfo({ bankid }, hre, runSuper) {
  const GeneralCBMT_Address = process.env.GENERAL_CBMT_EPN || process.env.GENERAL_CONTRACT_ADDRESS;

  const GeneralCBMT = await hre.ethers.getContractFactory("GeneralCBMT");
  const GeneralCBMT_Contract = await GeneralCBMT.attach(GeneralCBMT_Address);

  const [owner] = await hre.ethers.getSigners(); // use our own credentials
  const cbmt = GeneralCBMT_Contract.connect(owner);
  const info = await cbmt.getParticipatingBank(bankid);

  return cbmt_print_bankinfo(info, hre, runSuper );
}

async function cbmt_banks(args, hre, runSuper) {
  const GeneralCBMT_Address = process.env.GENERAL_CBMT_EPN || process.env.GENERAL_CONTRACT_ADDRESS;

  const GeneralCBMT = await hre.ethers.getContractFactory("GeneralCBMT");
  const GeneralCBMT_Contract = await GeneralCBMT.attach(GeneralCBMT_Address);

  const owner = await getSigner(hre); // use our own credentials
  const cbmt = GeneralCBMT_Contract.connect(owner);
  const banks = await cbmt.getParticipatingBanks();
  for (let bank of banks) {
      cbmt_print_bankinfo(bank);
  }
}

// Whitelist customer

async function thisBank(hre,cbmt) {
    const me = await getSigner(hre);
    const banks = await cbmt.getParticipatingBanks();
    // console.log(`me ${me.address}`);
    const [bank_info] = banks.filter( (e,i,b) => { return (
                                                  me.address == e._issuingAddress
                                               || me.address == e._mintAddress
                                               || me.address == e._redemptionAddress
                                               || me.address == e._generalAddress
                                               )});
    // console.log(`bank_info ${bank_info}`);
    return bank_info
}

async function cbmt_whitelist({ customer }, hre, runSuper) {
    const owner = await getSigner(hre); // use our own credentials
    const cbmt = (await getCBMTGeneral(hre)).connect(owner);
    const info = await thisBank(hre, cbmt);
    if( ! info) {
        console.log(`Could not find address ${owner.address} in bank list`);
        process.exit(-1);
    }
    const result = await cbmt.addToWhitelist( Number(info._bankId), customer );
    // can we output meaningful information here?
}

// Customer registers convert address
async function cbmt_register_convert_address({ customer, bankid }, hre, runSuper) {
    const owner = await getSigner(hre); // use our own credentials
    const cbmt = (await getCBMTGeneral(hre)).connect(owner);
    const result = await cbmt.registerCustomer( bankid, customer );
}

// Add currency to a convert address
async function cbmt_add_currency({ customer, currencyid }, hre, runSuper) {
    const owner = await getSigner(hre); // use our own credentials
    const cbmt = (await getCBMTGeneral(hre)).connect(owner);
    const info = await thisBank(hre, cbmt);
    if( ! info) {
        console.log(`Could not find address ${owner.address} in bank list`);
        process.exit(-1);
    }
    const result = await cbmt.addCurrencyToCustomer( info._bankId, customer, [currencyid] );
}

async function cbmt_info({}, hre, runSuper) {
    
  //const generalCBMT = await getGeneralCBMT(hre);

  const me = await getSigner(hre); // use our own credentials
  const cbmt = await getCBMTGeneral(hre);
  const cbmt_erc1155 = await getCBMT(hre);
  console.log("CBMT General version: " + await cbmt.getContractVersion());
  console.log("CBMT         version: " + await cbmt_erc1155.getContractVersion());

  let info = {
      mainAddress: me.address
  };

  // Find "this" bank
  const bank_info = await thisBank(hre, cbmt);
  if( bank_info ) {
      info.owner = 'bank';
      info.issuingAddress    = bank_info._issuingAddress;
      info.mintAddress       = bank_info._mintAddress;
      info.redemptionAddress = bank_info._redemptionAddress;
      info.generalAddress    = bank_info._generalAddress;
      info.name              = bank_info._name;
      info.bankId            = Number(bank_info._bankId);

      // getBankCustomers is not public...
      //info.customers         = await cbmt.getBankCustomers(info.bankId);

  } else if( ! bank_info) {
      // Are we a customer?
      const isCustomerGA = await cbmt.isCustomerGeneralAddress( me.address );
      const isCustomerCA = await cbmt.isCustomerConvertAddress( me.address );
      if( isCustomerGA || isCustomerCA ) {
          // Untested because we don't have those implemented yet
          // Yes
          info.owner = 'customer';
          if( isCustomerGA ) {
              info.generalAddress = me.address;

          } else {
              info.generalAddress = await cbmt.getCustomerGeneralAddress(me.address);
          }

          let customerAddresses = [];
          let maxBank = await cbmt.getCurrentBankId();

          for( let bank = 0; bank < maxBank; bank+= 1000) {
              let registeredWithBank = await cbmt.getCustomerConvertAddressFromGeneralAndBankId(info.generalAddress, bank);
              for (let addr of registeredWithBank) {
                  let currencies = [];
                  for( const curr of supportedCurrencies ) {
                      let supported = await cbmt.isCustomerSupportedCurrency( bank, addr, curr );
                      const preferred = await cbmt.isCustomerPreferredIssuerForCurrency(addr, curr, bank);
                      if( supported ) {
                          currencies.push({"curr":currencyNames[curr], "preferred":preferred});
                      }
                  }


                  customerAddresses.push( { "bank": bank, "convertAddress": addr, "currencies": currencies } );
              }
          }

          info.convertAddresses = customerAddresses;

      } else {
          // No
          info.owner = 'unregistered';
      }

  };

  console.log(util.inspect(info, {showHidden: false, depth: null}));
  await cbmt_balance({ account: me.address }, hre);
}

async function getCustomerConvertAddresses(hre, cbmt, customer, bank) {
    const isCustomerGA = await cbmt.isCustomerGeneralAddress( customer );
    bank ||= (await thisBank(hre, cbmt))._bankId;

    const addresses = [];
    if( isCustomerGA ) {
        addresses.push.apply( addresses, await cbmt.getCustomerConvertAddressFromGeneralAndBankId(customer, bank));
    } else {
        addresses.push(customer);
    }

    return addresses
}

/*

This function is useful when an amount is stuck on a convert address

*/

async function cbmt_cleanup_convert_address({ customer }, hre, runSuper) {
    // Should we maybe try to find _all_ convert addresses of our customers where any token still is on
    // and clean up these?
    const cbmtGeneral = await getCBMTGeneral(hre);
    const cbmt = await getCBMT(hre);
    const me = await thisBank(hre, cbmtGeneral);
    const banks = await cbmtGeneral.getParticipatingBanks();
    const generalAddress = await cbmtGeneral.getCustomerGeneralAddress( customer ) || customer;
    const addresses = await getCustomerConvertAddresses( hre, cbmtGeneral, generalAddress, me._bankId );
	const provider = hre.ethers.provider;
    const minter = (await getWallet('mint')).connect(provider);

    for( const addr of addresses ) {
        // XXX do a batch request for the address instead of iterating
        for(const bank of banks) {
            if( Number(bank._bankId) == me._bankId ) {
                continue
            }

            for(const currency of supportedCurrencies) {
                const tokenid = Number(bank._bankId)+currency;
                const amount = Number(await cbmt.balanceOf(addr, tokenid));
                if( Math.abs(amount) > 0.0000001) {
                    console.log(`Cleaning up ${addr} (${tokenid}); ${amount}; to ${generalAddress}`);
                    // We need to find out which case we have (2/4 or 3)
                    // Here we assume case 2/4 , unsupported issuer
                    const transaction = await cbmt.connect(minter).convertTokenFromNotSupportedIssuer( tokenid, me._bankId, currency, amount, addr );
                    await transaction.wait();
                }
            }
        }
    }
}

async function cbmt_send({ payer, receiver, amount, tokenid, label="CBMT text" }, hre, runSuper) {
  process.env.NODE_TLS_REJECT_UNAUTHORIZED=0;
  const base_amount = 100000000;
  label = textToUint8(label);
  const amountToTransfer = parseFloat(amount) * base_amount;
  const owner = await getSigner(hre, payer); // use supplied credentials, and properly decode the old addresses into their owner structure
  const sender = owner;
  const receiverAddress = receiver;

  const senderAddress = payer || sender.address;

  const cbmt = await getCBMT(hre);
  const cbmtGeneral = await getCBMTGeneral(hre);

  console.log('BEFORE transfer');
  await cbmt_balance( { account:senderAddress, tokenid }, hre);
  await cbmt_balance( { account:receiverAddress, tokenid }, hre);
  console.log(`Transfer token ${tokenid} from ${senderAddress} to ${receiver} (${(amountToTransfer/base_amount).toFixed(8)})`);
  
   
  const transfer = await cbmt.connect(sender).safeTransferFrom(senderAddress, receiverAddress, tokenid, amountToTransfer, label);
  console.log("Transfer initiated, awaiting confirmation...");
  console.log(transfer);
  const receipt = await transfer.wait();
  console.log('AFTER transfer');
  await cbmt_balance( { account:senderAddress, tokenid }, hre);

  const isCustomerCA = await cbmtGeneral.isCustomerConvertAddress( receiverAddress );
  let targetAddress = receiverAddress;
  if( isCustomerCA ) {
      targetAddress = await cbmtGeneral.getCustomerGeneralAddress(receiverAddress);
  }
  await cbmt_balance( { account:targetAddress, tokenid }, hre);
};

async function cbmt_stamp({ amount, currency=978, label="Stamp new tokens" }={}, hre, runSuper) {
	const cbmt_general = await getCBMTGeneral(hre);
	const bank = await thisBank(hre, cbmt_general);
	if( ! bank) {
        const envname = process.env.ENVNAME || '<unknown>';
		console.error(`We are running as ${envname}, not as a bank`);
		process.exit(-1);
	};
    label = textToUint8(label);
    
	amount = parseFloat(amount,10);

	const cbmt = await getCBMT(hre);

	// Here I need two kinds of credentials ...
	const provider = hre.ethers.provider;
	const issuerWallet = (await getWallet('issuing')).connect(provider);
	const minterWallet = (await getWallet('mint')).connect(provider);

	console.log(`Requesting %f tokens to ${issuerWallet.address}`, amount);
	const requestBlankToken = await cbmt.connect( issuerWallet ).requestBlankToken( bank._bankId, currency, amount*base_amount );
	await requestBlankToken.wait();
	console.log(`Stamping %f tokens to ${minterWallet.address}`, amount);
	const stampToken = await cbmt.connect( minterWallet ).stampToken( bank._bankId, currency, amount*base_amount, label );
	await stampToken.wait();

	await cbmt_balance( { account:bank._mintAddress }, hre);
}

async function cbmt_supply({ customer, amount, currency=978, label="" }={}, hre, runSuper) {
	const cbmt_general = await getCBMTGeneral(hre);
	const bank = await thisBank(hre, cbmt_general);
	if( ! bank) {
        const envname = process.env.ENVNAME || '<unknown>';
		console.error(`We are running as ${envname}, not as a bank`);
		process.exit(-1);
	};
    label = textToUint8(label);

	amount = parseFloat(amount,10);

	const cbmt = await getCBMT(hre);

	const provider = hre.ethers.provider;
	const minterWallet = (await getWallet('mint')).connect(provider);

	console.log(`Requesting ${amount} tokens ${currency} of ${bank._bankId} to ${customer}`);
    
    const requestBlankToken = await cbmt.connect( minterWallet ).requestTokenFromCustomer( bank._bankId, customer, currency, amount*base_amount );
	await requestBlankToken.wait();

	await cbmt_balance( { account:customer }, hre);
}

async function do_cbmt_gas(taskArgs, hre, runSuper) {
    return cbmt_gas(taskArgs, hre)
}

async function do_cbmt_send(taskArgs, hre, runSuper) {
    return cbmt_send(taskArgs, hre)
}

async function do_cbmt_stamp(taskArgs, hre, runSuper) {
    return cbmt_stamp(taskArgs, hre)
}

async function do_cbmt_supply(taskArgs, hre, runSuper) {
    return cbmt_supply(taskArgs, hre)
}

async function do_cbmt_balance(taskArgs, hre, runSuper) {
    return cbmt_balance(taskArgs, hre)
}

async function do_cbmt_bankinfo(taskArgs, hre, runSuper) {
    return cbmt_bankinfo(taskArgs, hre)
}

async function do_cbmt_banks(taskArgs, hre, runSuper) {
    return cbmt_banks(taskArgs, hre)
}

async function do_cbmt_add_bank(taskArgs, hre, runSuper) {
    return cbmt_add_bank(taskArgs, hre)
}

async function do_cbmt_add_currency(taskArgs, hre, runSuper) {
    return cbmt_add_currency(taskArgs, hre)
}

async function do_cbmt_addresses(taskArgs, hre, runSuper) {
    return cbmt_addresses(taskArgs, hre)
}

async function do_cbmt_cleanup_convert_address(taskArgs, hre, runSuper) {
    return cbmt_cleanup_convert_address(taskArgs, hre)
}

async function do_cbmt_info(taskArgs, hre, runSuper) {
    return cbmt_info(taskArgs, hre)
}

async function do_cbmt_register_convert_address(taskArgs, hre, runSuper) {
    return cbmt_register_convert_address(taskArgs, hre)
}

async function do_cbmt_whitelist(taskArgs, hre, runSuper) {
    return cbmt_whitelist(taskArgs, hre)
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function log(tx) {

  const message = `https://explorer.evan.network/tx/${tx.hash}`;

  console.log("You can see the tx status:" + message);

  try {
    await fs.appendFile('transaction-hash.txt', message + '\n');
  } catch (err) {
    console.error('Error writing to file', err);
  }
}

// Set up tasks
//console.log(cfg);
//const cbmt = cfg.task("cbmt", "CBMT commands");
//console.log(cbmt);
cfg.task("cbmt-balance", "Show CBMT balance of an account")
  .addOptionalParam("as", "The config file to load")
  .addOptionalParam("account", "The account's address (0x1234...)")
  .addOptionalParam("tokenid", "The token ID (issuer+currency)")
  .setAction(do_cbmt_balance);

cfg.task("cbmt-send", "Sends CBMT from the current account to the receiver")
  .addOptionalParam("as", "The config file to load")
  .addOptionalParam("payer", "The payer's address (0x1234...)")
  .addParam("receiver", "The account's address (0x1234...)")
  .addParam("amount", "The amount (3.141592)")
  .addParam("tokenid", "The token ID (issuer+currency)")
  .setAction(do_cbmt_send);

cfg.task("cbmt-stamp", "[Bank] Creates blank tokens and stamps them in one step")
  .addOptionalParam("as", "The config file to load")
  .addOptionalParam("label", "The label for the transaction")
  .addParam("amount", "The amount (3.141592)")
  .addOptionalParam("currency", "The currency")
  .setAction(do_cbmt_stamp);

cfg.task("cbmt-supply", "[Bank] Supply CBMT to a customer")
  .addOptionalParam("as", "The config file to load")
  .addParam("customer", "The general address of the customer")
  .addParam("amount", "The amount (3.141592)")
  .addOptionalParam("currency", "The currency")
  .setAction(do_cbmt_supply);

cfg.task("cbmt-gas", "Fund a CBMT account with gas")
  .addOptionalParam("as", "The config file to load")
  .addParam("receiver", "The account's address (0x1234...)")
  .addParam("amount", "The amount (3.141592)")
  .setAction(do_cbmt_gas);

cfg.task("cbmt-bankinfo", "Print information on a single bank id")
  .addOptionalParam("as", "The config file to load")
  .addParam("bankid", "The bank id (100)")
  .setAction(do_cbmt_bankinfo);

cfg.task("cbmt-banks", "List all participating banks")
  .addParam("as", "The config file to load")
  .setAction(do_cbmt_banks);

cfg.task("cbmt-add-bank", "(TSP) Add a new bank")
  .addOptionalParam("as", "The config file to load")
  .addParam("issuing", "The issuing address (0x1234...)")
  .addParam("mint", "The minting address (0x1234...)")
  .addParam("redemption", "The redemption address (0x1234...)")
  .addParam("general", "The general address (0x1234...)")
  .addParam("name", "Name of the bank")
  .setAction(do_cbmt_add_bank);

cfg.task("cbmt-add-currency", "[Bank] Add a supported currency to a convert address")
  .addOptionalParam("as", "The config file to load")
  .addParam("customer", "The Convert Address of the customer")
  .addParam("currencyid", "The id of the currency")
  .setAction(do_cbmt_add_currency);

cfg.task("cbmt-addresses", "[TSP] List all addresses")
  .addOptionalParam("as", "The config file to load")
  .setAction(do_cbmt_addresses);

cfg.task("cbmt-cleanup-convert-address", "[Bank] Clean up money stuck on a convert address")
  .addOptionalParam("as", "The config file to load")
  .addParam("customer", "The Convert or General Address of the customer")
  .setAction(do_cbmt_cleanup_convert_address);

cfg.task("cbmt-info", "Output information on this CBMT account")
  .addOptionalParam("as", "The config file to load")
  .setAction(do_cbmt_info);

cfg.task("cbmt-register-convert-address", "[Customer CA] Register a convert address to our general address")
  .addOptionalParam("as", "The config file to load")
  .addParam("customer", "The General Address of the customer")
  .addParam("bankid", "The bank id to associate with the convert address")
  .setAction(do_cbmt_register_convert_address);

cfg.task("cbmt-whitelist", "[Bank] Whitelist a customer general address")
  .addOptionalParam("as", "The config file to load")
  .addParam("customer", "The General Address of the customer")
  .setAction(do_cbmt_whitelist);
