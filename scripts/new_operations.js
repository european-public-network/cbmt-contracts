require('dotenv');
const { ethers } = require("hardhat");
const { Wallet } = require('ethers');
const fs = require('fs-extra');
const readline = require("readline");
const dotenv = require('dotenv');
const path = require('path');

function loadEnvFile(filePath) {
  const fullPath = path.resolve(__dirname, filePath);
  if (!fs.existsSync(fullPath)) {
    throw new Error("File does not exist");
  }
  return dotenv.parse(fs.readFileSync(fullPath));
}

const main = async () => {
  const provider = hre.ethers.provider;
  process.env.NODE_TLS_REJECT_UNAUTHORIZED=0;
  // CHG002
  const supportedCurrencies = [978, 840]
  const EUR_ID = supportedCurrencies[0];
  const USD_ID = supportedCurrencies[1];
  // CHG001
  const base_amount = 100000000;

  const bank_1_id = 100;
  const bank_2_id = 200;
  const bank_3_id = 300;
  const amountRequested = 100000 * base_amount;
  const amountToTransfer = 100 * base_amount;
  const amountToReturn = 100 * base_amount;
  const amountToBankTransfer = 100000 * base_amount;
  const amountForBankTransfer = 10000 * base_amount;
  const amountToNetSettle = 100 * base_amount;
  const amountToGrossSettle = 100 * base_amount;
  const label = 1;

  const [ owner, bank1Issuing, bank1Mint, bank1Redemption, bank1General, bank2Issuing, bank2Mint, bank2Redemption, bank2General, customer1General, 
    customer1Convert, customer2General, customer2Convert, customer3General, customer3Convert 
  ] = await ethers.getSigners();
  
  const bank3IssuerConfig = loadEnvFile('../.unicredit-issuer.env');
  const bank3MintConfig = loadEnvFile('../.unicredit-mint.env');
  const bank3GeneralConfig = loadEnvFile('../.unicredit.env');

  const customer4General_Config = loadEnvFile('../.escrow1-ga.env'); 
  const customer4Convert_Config = loadEnvFile('../.escrow1-ca.env');

  const arbiter_Config = loadEnvFile('../.arbiter.env');

  const bank3Issuer_mnemonic = bank3IssuerConfig.MNEMONIC;
  const bank3Mint_mnemonic = bank3MintConfig.MNEMONIC;
  const bank3General_mnemonic = bank3GeneralConfig.MNEMONIC;
  const customer4General_mnemonic = customer4General_Config.MNEMONIC; 
  const customer4Convert_mnemonic = customer4Convert_Config.MNEMONIC;
  const arbiter_mnemonic = arbiter_Config.MNEMONIC;

  const bank3Issuing = ethers.Wallet.fromMnemonic(bank3Issuer_mnemonic).connect(provider); 
  const bank3Mint = ethers.Wallet.fromMnemonic(bank3Mint_mnemonic).connect(provider); 
  const bank3General = ethers.Wallet.fromMnemonic(bank3General_mnemonic).connect(provider);
  const customer4General = ethers.Wallet.fromMnemonic(customer4General_mnemonic).connect(provider); 
  const customer4Convert = ethers.Wallet.fromMnemonic(customer4Convert_mnemonic).connect(provider);
  const arbiter = ethers.Wallet.fromMnemonic(arbiter_mnemonic).connect(provider);  
  
  const epnConfig = loadEnvFile('../.env');
  const GeneralCBMT_Address = epnConfig.GENERAL_CBMT_EPN;
  const CBMT_Address = epnConfig.CBMT_EPN;
  const EscrowCBMT_Address = epnConfig.ESCROWCBMT_EPN;

  const GeneralCBMT = await hre.ethers.getContractFactory("GeneralCBMT");
  const GeneralCBMT_Contract = await GeneralCBMT.attach(GeneralCBMT_Address);

  const CBMT = await hre.ethers.getContractFactory("CBMT");
  const CBMT_Contract = await CBMT.attach(CBMT_Address);

  const EscrowCBMT = await hre.ethers.getContractFactory("EscrowCBMT");
  const EscrowCBMT_Contract = await EscrowCBMT.attach(EscrowCBMT_Address);

  const bank1TokenIdEUR = await CBMT_Contract.getTokenIdFromBankId(bank_1_id, EUR_ID);
  const bank1TokenIdUSD = await CBMT_Contract.getTokenIdFromBankId(bank_1_id, USD_ID);
  const bank2TokenIdEUR = await CBMT_Contract.getTokenIdFromBankId(bank_2_id, EUR_ID);
  const bank2TokenIdUSD = await CBMT_Contract.getTokenIdFromBankId(bank_2_id, USD_ID);
  const bank3TokenIdEUR = await CBMT_Contract.getTokenIdFromBankId(bank_3_id, EUR_ID);
  const bank3TokenIdUSD = await CBMT_Contract.getTokenIdFromBankId(bank_3_id, USD_ID);
 
  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`REQUEST TOKEN`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(1) Customer 1 requests 100,000 EUR in token to Bank DZ");
  const customer1RequestEURToken_ToBank_A = await CBMT_Contract.connect( bank1Mint ).requestTokenFromCustomer( bank_1_id, customer1General.address, EUR_ID, amountRequested );
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber1 = await customer1RequestEURToken_ToBank_A.wait(3);
  await log(customer1RequestEURToken_ToBank_A, blockNumber1.blockNumber);
  console.log(blockNumber1.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(2) Customer 2 requests 100,000 EUR in token to Bank DZ");
  const customer2RequestEURToken_ToBank_A = await CBMT_Contract.connect( bank1Mint ).requestTokenFromCustomer( bank_1_id, customer2General.address, EUR_ID, amountRequested );
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber2 = await customer2RequestEURToken_ToBank_A.wait(3);
  await log(customer2RequestEURToken_ToBank_A, blockNumber2.blockNumber);
  console.log(blockNumber2.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(3) Customer 4 requests 100,000 USD in token to Bank DZ");
  const customer4RequestEURToken_ToBank_A = await CBMT_Contract.connect( bank1Mint ).requestTokenFromCustomer( bank_1_id, customer4General.address, USD_ID, amountRequested );
  const blockNumber3 = await customer4RequestEURToken_ToBank_A.wait(3);
  await log(customer4RequestEURToken_ToBank_A, blockNumber3.blockNumber);
  console.log(blockNumber3.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`GENERAL -> GENERAL (BOOKING ERROR)`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(4) Customer 1 transfers 100 € in CBMT Tokens (EUR) to Customer 3's General address (Direct transfer)"); 
  const transferToGeneral_1 = await CBMT_Contract.connect( customer1General ).safeTransferFrom(customer1General.address, customer3General.address, bank1TokenIdEUR, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber4 = await transferToGeneral_1.wait(3);
  await log(transferToGeneral_1, blockNumber4.blockNumber);
  console.log(blockNumber4.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`GENERAL -> GENERAL (NOT SUPPORTED CURRENCY)`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(5) Customer 4 transfers 100 $ in CBMT Tokens (USD) to Customer 1's General address (Direct transfer)"); 
  const transferToGeneral_2 = await CBMT_Contract.connect( customer4General ).safeTransferFrom(customer4General.address, customer1General.address, bank1TokenIdUSD, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber5 = await transferToGeneral_2.wait(3);
  await log(transferToGeneral_2, blockNumber5.blockNumber);
  console.log(blockNumber5.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`GENERAL -> GENERAL (SUPPORTED CURRENCY)`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(6) Customer 2 transfers 100 € in CBMT Tokens (EUR) to Customer 1's General address (Direct transfer)"); 
  const transferToGeneral_3 = await CBMT_Contract.connect( customer2General ).safeTransferFrom(customer2General.address, customer1General.address, bank1TokenIdEUR, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber6 = await transferToGeneral_3.wait(3);
  await log(transferToGeneral_3, blockNumber6.blockNumber);
  console.log(blockNumber6.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`TRANSFER TOKEN SUPPORTED ISSUER AND CURRENCY`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(7) Customer 1 transfer 100 € in CBMT Tokens (EUR) to Customer 2's Convert address"); 
  const transferToSupportedConvertAddress = await CBMT_Contract.connect( customer1General ).safeTransferFrom(customer1General.address, customer2Convert.address, bank1TokenIdEUR, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber7 = await transferToSupportedConvertAddress.wait(3);
  await log(transferToSupportedConvertAddress, blockNumber7.blockNumber);
  console.log(blockNumber7.blockNumber);
  console.log(``);

  await sleep(3000);
  
  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`TRANSFER TO CONVERT SUPPORTED ISSUER & NOT SUPPORTED CURRENCY`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(8) Customer 1 transfer 100 € in CBMT Tokens (EUR) to Customer 4's Convert address"); 
  const transferToSupportedConvertAddressNotCurrency = await CBMT_Contract.connect(customer1General).safeTransferFrom(customer1General.address, customer4Convert.address, bank1TokenIdEUR, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber8 = await transferToSupportedConvertAddressNotCurrency.wait(3);
  await log(transferToSupportedConvertAddressNotCurrency, blockNumber8.blockNumber);
  console.log(blockNumber8.blockNumber);
  console.log(``);

  await sleep(3000)

  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`TRANSFER TO CONVERT NOT SUPPORTED ISSUER & SUPPORTED CURRENCY (DZ PERFORM CONVERSION)`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(9) Customer 3 transfer 100 € in CBMT Tokens (EUR) to Customer 1's Convert address"); 
  const transferToConvert_1 = await CBMT_Contract.connect(customer3General).safeTransferFrom(customer3General.address, customer1Convert.address, bank2TokenIdEUR, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber9 = await transferToConvert_1.wait(3);
  await log(transferToConvert_1, blockNumber9.blockNumber);
  console.log(blockNumber9.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`TRANSFER TO CONVERT NOT SUPPORTED ISSUER & SUPPORTED CURRENCY (GENERIC BANK PERFORM CONVERSION)`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(10) Customer 1 transfer 100 € in CBMT Tokens (EUR) to Customer 3's Convert address"); 
  const transferToConvert_2 = await CBMT_Contract.connect(customer1General).safeTransferFrom(customer1General.address, customer3Convert.address, bank1TokenIdEUR, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber10 = await transferToConvert_2.wait(3);
  await log(transferToConvert_2, blockNumber10.blockNumber);
  console.log(blockNumber10.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`TRANSFER TO CONVERT NOT SUPPORTED ISSUER & CURRENCY (DZ PERFORM CONVERSION)`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(11) Customer 3 transfer 100 € in CBMT Tokens (EUR) to Customer 4's Convert address"); 
  const transferToConvert_3 = await CBMT_Contract.connect(customer3General).safeTransferFrom(customer3General.address, customer4Convert.address, bank2TokenIdEUR, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber11 = await transferToConvert_3.wait(3);
  await log(transferToConvert_3, blockNumber11.blockNumber);
  console.log(blockNumber11.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`TRANSFER TO CONVERT NOT SUPPORTED ISSUER & CURRENCY (GENERIC BANK PERFORM CONVERSION)`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(12) Customer 4 transfer 100 $ in CBMT Tokens (USD) to Customer 3's Convert address"); 
  const transferToConvert_4 = await CBMT_Contract.connect(customer4General).safeTransferFrom(customer4General.address, customer3Convert.address, bank1TokenIdUSD, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber12 = await transferToConvert_4.wait(3);
  await log(transferToConvert_4, blockNumber12.blockNumber);
  console.log(blockNumber12.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log(``);
  console.log("------------------------------------");
  console.log("BANK TRANSFERS");
  console.log("------------------------------------");
  console.log(``);

  console.log(`Internal transfers from mint to general`);
  console.log(`Bank DZ`);
  const internalTransferFromBank_A = await CBMT_Contract.connect(bank1Mint).transfer( bank_1_id, bank1General.address, bank1TokenIdEUR, amountToBankTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  await internalTransferFromBank_A.wait(3);
  await log(internalTransferFromBank_A);
  console.log(``);

  await sleep(3000);
  
  console.log(`Bank B`);
  const internalTransferFromBank_B = await CBMT_Contract.connect(bank2Mint).transfer( bank_2_id, bank2General.address, bank2TokenIdEUR, amountToBankTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  await internalTransferFromBank_B.wait(3);
  await log(internalTransferFromBank_B);
  console.log(``);

  await sleep(3000);

  console.log(`Bank C`);
  const internalTransferFromBank_C = await CBMT_Contract.connect(bank3Mint).transfer( bank_3_id, bank3General.address, bank3TokenIdEUR, amountToBankTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  await internalTransferFromBank_C.wait(3);
  await log(internalTransferFromBank_C);
  console.log(``);

  await sleep(3000);

  console.log("(13) Bank DZ transfers own tokens to Bank B"); 
  const transferFromDZToBankB = await CBMT_Contract.connect(bank1General).transfer( bank_1_id, bank2General.address, bank1TokenIdEUR, amountForBankTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber13 = await transferFromDZToBankB.wait(3);
  await log(transferFromDZToBankB, blockNumber13.blockNumber);
  console.log(blockNumber13.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(14) Bank DZ transfers own tokens to Bank C"); 
  const transferFromDZToBankC = await CBMT_Contract.connect(bank1General).transfer( bank_1_id, bank3General.address, bank1TokenIdEUR, amountForBankTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber14 = await transferFromDZToBankC.wait(3);
  await log(transferFromDZToBankC, blockNumber14.blockNumber);
  console.log(blockNumber14.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(15) Bank B transfers own tokens to Bank DZ"); 
  const transferFromBToBankDZ = await CBMT_Contract.connect(bank2General).transfer( bank_2_id, bank1General.address, bank2TokenIdEUR, amountForBankTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber15 = await transferFromBToBankDZ.wait(3);
  await log(transferFromBToBankDZ, blockNumber15.blockNumber);
  console.log(blockNumber15.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(16) Bank C transfers own tokens to Bank DZ"); 
  const transferFromCToBankDZ = await CBMT_Contract.connect(bank3General).transfer( bank_3_id, bank1General.address, bank3TokenIdEUR, amountForBankTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber16 = await transferFromCToBankDZ.wait(3);
  await log(transferFromCToBankDZ, blockNumber16.blockNumber);
  console.log(blockNumber16.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(17) Bank B transfers Bank DZ tokens to Bank DZ"); 
  const transferFromBank_3 = await CBMT_Contract.connect(bank2General).transfer( bank_2_id, bank1General.address, bank1TokenIdEUR, amountToTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber17 = await transferFromBank_3.wait(3);
  await log(transferFromBank_3, blockNumber17.blockNumber);
  console.log(blockNumber17.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(18) Bank B transfers Bank DZ tokens to Bank C"); 
  const transferFromBank_4 = await CBMT_Contract.connect(bank2General).transfer( bank_2_id, bank3General.address, bank1TokenIdEUR, amountToTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber18 = await transferFromBank_4.wait(3);
  await log(transferFromBank_4, blockNumber18.blockNumber);
  console.log(blockNumber18.blockNumber);
  console.log(``);

  await sleep(3000);


  console.log("(19) Bank DZ transfers not own tokens to Bank B"); 
  const transferFromBank_5 = await CBMT_Contract.connect(bank1General).transfer( bank_1_id, bank2General.address, bank2TokenIdEUR, amountToTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber19 = await transferFromBank_5.wait(3);
  await log(transferFromBank_5, blockNumber19.blockNumber);
  console.log(blockNumber19.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(20) Bank DZ transfers own tokens to Customer 1"); 
  const transferFromBank_6 = await CBMT_Contract.connect(bank1General).transfer( bank_1_id, customer1General.address, bank1TokenIdEUR, amountToTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber20 = await transferFromBank_6.wait(3);
  await log(transferFromBank_6, blockNumber20.blockNumber);
  console.log(blockNumber20.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(21) Bank DZ removes from whitelist Customer 4");
  const removeFromWhitelistCustomer4FromBank_A = await GeneralCBMT_Contract.connect( bank1Mint ).removeFromWhitelist( bank_1_id, customer4General.address);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber21 = await removeFromWhitelistCustomer4FromBank_A.wait(3);
  await log(removeFromWhitelistCustomer4FromBank_A, blockNumber21.blockNumber);
  console.log(blockNumber21.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(22) Bank DZ transfers own tokens to Customer 4 (no longer whitelisted)"); 
  const transferFromBank_7 = await CBMT_Contract.connect(bank1General).transfer( bank_1_id, customer4General.address, bank1TokenIdEUR, amountToTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber22 = await transferFromBank_7.wait(3);
  await log(transferFromBank_7, blockNumber22.blockNumber);
  console.log(blockNumber22.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(23) Bank DZ transfer not own tokens to Customer 1"); 
  const transferFromBank_8 = await CBMT_Contract.connect(bank1General).transfer( bank_1_id, customer1General.address, bank2TokenIdEUR, amountToTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber23 =  await transferFromBank_8.wait(3);
  await log(transferFromBank_8, blockNumber23.blockNumber);
  console.log(blockNumber23.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(24) Bank B transfer DZ tokens to Customer 3");
  const transferFromBank_9 = await CBMT_Contract.connect(bank2General).transfer( bank_2_id, customer3General.address, bank1TokenIdEUR, amountToTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber24 = await transferFromBank_9.wait(3);
  await log(transferFromBank_9, blockNumber24.blockNumber);
  console.log(blockNumber24.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(25) Bank B transfers DZ tokens to Customer 1");
  const transferFromBank_10 = await CBMT_Contract.connect(bank2General).transfer( bank_2_id, customer1General.address, bank1TokenIdEUR, amountToTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber25 = await transferFromBank_10.wait(3);
  await log(transferFromBank_10, blockNumber25.blockNumber);
  console.log(blockNumber25.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(26) Bank B transfers DZ tokens to Customer 4 (no longer whitelisted)"); 
  const transferFromBank_11 = await CBMT_Contract.connect(bank2General).transfer( bank_2_id, customer4General.address, bank1TokenIdEUR, amountToTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber26 = await transferFromBank_11.wait(3);
  await log(transferFromBank_11, blockNumber26.blockNumber);
  console.log(blockNumber26.blockNumber);
  console.log(``);  

  console.log(``);
  console.log("------------------------------------");
  console.log("INTERBANK SETTLEMENT");
  console.log("------------------------------------");
  console.log(``);

  console.log("(27) Bank DZ starts Net Settlement towards Bank B"); 
  const startNetSettlement = await CBMT_Contract.connect(bank1General).startNetSettlement(bank_1_id, bank_2_id, EUR_ID, amountToNetSettle);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber27 = await startNetSettlement.wait(3);
  await log(startNetSettlement, blockNumber27.blockNumber);
  console.log(blockNumber27.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(28) Bank DZ starts Gross Settlement towards Bank C"); 
  const startGrossSettlement_1 = await CBMT_Contract.connect(bank1General).grossSettlement(bank_1_id, bank_3_id, EUR_ID, amountToGrossSettle);
  console.log(``);  
  console.log("Settlement initiated, awaiting confirmation...");
  const blockNumber28 = await startGrossSettlement_1.wait(3);
  await log(startGrossSettlement_1, blockNumber28.blockNumber);
  console.log(blockNumber28.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(29) Bank B starts Net Settlement towards Bank DZ"); 
  const startNetSettlement2 = await CBMT_Contract.connect(bank2General).startNetSettlement(bank_2_id, bank_1_id, EUR_ID, amountToNetSettle);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber29 = await startNetSettlement2.wait(3);
  await log(startNetSettlement, blockNumber29.blockNumber);
  console.log(blockNumber29.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(30) Bank B starts Gross Settlement towards Bank DZ"); 
  const startGrossSettlement_2 = await CBMT_Contract.connect(bank2General).grossSettlement(bank_2_id, bank_1_id, EUR_ID, amountToGrossSettle);
  console.log(``);  
  console.log("Settlement initiated, awaiting confirmation...");
  const blockNumber30 = await startGrossSettlement_2.wait(3);
  await log(startGrossSettlement_2, blockNumber30.blockNumber);
  console.log(blockNumber30.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(31) DZ Bank add USD to Customer 1"); 
  const addCurrencyToCustomer1 = await GeneralCBMT_Contract.connect(bank1General).addCurrencyToCustomer(bank_1_id, customer1Convert.address, [USD_ID]);
  console.log(``);  
  console.log("Operation initiated, awaiting confirmation...");
  const blockNumber31 = await addCurrencyToCustomer1.wait(3);
  await log(addCurrencyToCustomer1, blockNumber31.blockNumber);
  console.log(blockNumber31.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(32) Bank B whitelist Customer 4");
  const whitelistCustomer4FromBank_2 = await GeneralCBMT_Contract.connect( bank2Mint ).addToWhitelist( bank_2_id, customer4General.address);
  console.log(``);  
  console.log("Operation initiated, awaiting confirmation...");
  const blockNumber32 = await whitelistCustomer4FromBank_2.wait(3);
  await log(whitelistCustomer4FromBank_2, blockNumber32.blockNumber);
  console.log(blockNumber32.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(33) Customer 1 transfer 100 € in CBMT Tokens (EUR) to Customer 4's General address (Direct transfer)"); 
  const transferToGeneral_4 = await CBMT_Contract.connect(customer1General).safeTransferFrom(customer1General.address, customer4General.address, bank1TokenIdEUR, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber33 = await transferToGeneral_4.wait(3);
  await log(transferToGeneral_4, blockNumber33.blockNumber);
  console.log(blockNumber33.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(34) Bank B remove from whitelist Customer 4");
  const removeFromWhitelistCustomer4FromBank_B = await GeneralCBMT_Contract.connect( bank2Mint ).removeFromWhitelist( bank_2_id, customer4General.address);
  console.log(``);
  console.log("Operation initiated, awaiting confirmation...");
  const blockNumber34 = await removeFromWhitelistCustomer4FromBank_B.wait(3);
  await log(removeFromWhitelistCustomer4FromBank_B, blockNumber34.blockNumber);
  console.log(blockNumber34.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(35) Bank DZ whitelist Customer 4");
  const whitelistCustomer4FromBank_DZ = await GeneralCBMT_Contract.connect( bank1Mint ).addToWhitelist( bank_1_id, customer4General.address);
  console.log(``);
  console.log("Operation initiated, awaiting confirmation...");
  await whitelistCustomer4FromBank_DZ.wait(3);
  await log(whitelistCustomer4FromBank_DZ);
  console.log(``);

  await sleep(3000);

  console.log("(36) Customer 4 register to Bank DZ");
  const registerCustomer4ToBank_A= await GeneralCBMT_Contract.connect( customer4Convert ).registerCustomer( bank_1_id, customer4General.address);
  console.log(``);
  console.log("Operation initiated, awaiting confirmation...");
  await registerCustomer4ToBank_A.wait(3);
  await log(registerCustomer4ToBank_A);
  console.log(``);

  await sleep(3000);

  console.log("(37) Bank DZ adds USD currency to Customer 4");
  const addCurrencyToCustomer4FromBank_A = await GeneralCBMT_Contract.connect( bank1Mint ).addCurrencyToCustomer( bank_1_id, customer4Convert.address, [ USD_ID ]);
  console.log(``);
  console.log("Operation initiated, awaiting confirmation...");
  await addCurrencyToCustomer4FromBank_A.wait(3);
  await log(addCurrencyToCustomer4FromBank_A);
  console.log(``);

  await sleep(3000);

  console.log("(38) Bank DZ removes EUR currency from Customer 4");
  const removeCurrencyFrom4 = await GeneralCBMT_Contract.connect( bank1Mint ).removeCurrencyFromCustomer( bank_1_id, customer4Convert.address, EUR_ID );
  console.log(``);
  console.log("Operation initiated, awaiting confirmation...");
  await removeCurrencyFrom4.wait(3);
  await log(removeCurrencyFrom4);
  console.log(``);
  
  await sleep(3000);

  console.log("(39) Customer 1 transfer 100 € in CBMT Tokens (EUR) to Customer 4's Convert address"); 
  const transferToSupportedConvertAddressNotCurrency2 = await CBMT_Contract.connect(customer1General).safeTransferFrom(customer1General.address, customer4Convert.address, bank1TokenIdEUR, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber39 = await transferToSupportedConvertAddressNotCurrency2.wait(3);
  await log(transferToSupportedConvertAddressNotCurrency2, blockNumber39.blockNumber);
  console.log(blockNumber39.blockNumber);
  console.log(``);

  await sleep(3000)

  console.log("(40) Bank DZ remove USD currency from Customer 1");
  const removeCurrencyFrom1 = await GeneralCBMT_Contract.connect( bank1General ).removeCurrencyFromCustomer( bank_1_id, customer1Convert.address, USD_ID );
  const blockNumber40 = await removeCurrencyFrom1.wait(3);
  await log(removeCurrencyFrom1, blockNumber40.blockNumber);
  console.log(blockNumber40.blockNumber);
  console.log(``); 

  await sleep(3000);

  console.log("(41) Customer 4 transfer 100 $ in CBMT Tokens (USD) to Customer 1's Convert address"); 
  const transferToSupportedConvertAddressNotCurrency3 = await CBMT_Contract.connect(customer4General).safeTransferFrom(customer4General.address, customer1Convert.address, bank1TokenIdUSD, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber41 = await transferToSupportedConvertAddressNotCurrency3.wait(3);
  await log(transferToSupportedConvertAddressNotCurrency3, blockNumber41.blockNumber);
  console.log(blockNumber41.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`RETURN TOKENS`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(42) Customer 1 returns 100 € in CBMT Tokens (EUR) to DZ Bank"); 
  const returnTokens = await CBMT_Contract.connect(customer1General).returnTokens(bank_1_id, EUR_ID, amountToReturn);
  console.log(``);
  console.log("Operation initiated, awaiting confirmation...");
  const blockNumber42 = await returnTokens.wait(3);
  await log(returnTokens, blockNumber42.blockNumber);
  console.log(blockNumber42.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(43) Customer 4 returns 100 $ in CBMT Tokens (USD) to DZ Bank"); 
  const returnTokens2 = await CBMT_Contract.connect(customer4General).returnTokens(bank_1_id, USD_ID, amountToReturn);
  console.log(``);
  console.log("Operation initiated, awaiting confirmation...");
  const blockNumber43 = await returnTokens2.wait(3);
  await log(returnTokens2, blockNumber43.blockNumber);
  console.log(blockNumber43.blockNumber);
  console.log(``);

  await sleep(3000);

  const block = await provider.getBlock();
  const lockedTimestamp1 = block.timestamp + FIVE_DAYS_SECONDS;
  const depositDeadline1 = block.timestamp + TWO_DAYS_SECONDS;

  console.log(``);
  console.log(`----------------------------------------------`);
  console.log(`SMART CONTRACT TRANSACTION`);
  console.log(`----------------------------------------------`);
  console.log(``);

  console.log("(44) Customer 1 sets Escrow contract conditions"); 
  const setConditionEscrow1 = await EscrowCBMT_Contract.connect(customer1General).setEscrowContractConditions(
    customer2Convert.address,
    arbiter.address,
    lockedTimestamp1,
    depositDeadline1,
    amountToTransfer,
    EUR_ID
  );
  console.log("Operation initiated, awaiting confirmation...");
  await setConditionEscrow1.wait(3);
  await log(setConditionEscrow1);

  const escrowContractID_1 = await EscrowCBMT_Contract.nextContractId() - 1;
  
  await sleep(3000);

  console.log("(45) Customer 2 accepts Escrow contract conditions"); 
  const accept1 = await EscrowCBMT_Contract.connect(customer2General).acceptEscrowContractConditions(escrowContractID_1);
  console.log("Operation initiated, awaiting confirmation...");
  await accept1.wait(3);
  await log(accept1);
  console.log(``);

  await sleep(3000);

  console.log("(46) Customer 1 approves Escrow contract"); 
  const approve = await CBMT_Contract.connect(customer1General).setApprovalForAll( EscrowCBMT_Contract.address, true);
  await approve.wait(3);
  await log(approve);
  console.log(``);

  await sleep(3000);

  console.log("(47) Customer 1 deposits funds in the Escrow contract"); 
  const deposit1 = await EscrowCBMT_Contract.connect(customer1General).escrowContractDeposit(escrowContractID_1, bank1TokenIdEUR );
  console.log("Transaction initiated, awaiting confirmation...");
  const blockNumber47 = await deposit1.wait(3);
  await log(deposit1, blockNumber47.blockNumber);
  console.log(blockNumber47.blockNumber);
  console.log(``);

  await sleep(3000);

  console.log("(48) Arbiter releases funds from Escrow contract"); 
  const release1 = await EscrowCBMT_Contract.connect(arbiter).approveReleaseFunds(escrowContractID_1);
  console.log("Transaction initiated, awaiting confirmation...");
  const blockNumber48 = await release1.wait(3);
  await log(release1, blockNumber48.blockNumber);
  console.log(blockNumber48.blockNumber);

  await sleep(3000);

  console.log("(49) Bank DZ transfers own tokens to Customer 4"); 
  const transferFromBank_12 = await CBMT_Contract.connect(bank1General).transfer( bank_1_id, customer4General.address, bank1TokenIdEUR, amountToTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber49 = await transferFromBank_12.wait(3);
  await log(transferFromBank_12, blockNumber49.blockNumber);
  console.log(blockNumber49.blockNumber);
  console.log(``);
  
  await sleep(3000);

  console.log("(50) Transfer from Bank DZ own token to Escrow contract"); 
  const transferFromBankToContract = await CBMT_Contract.connect(bank1General).transfer( bank_1_id, EscrowCBMT_Contract.address, bank1TokenIdEUR, amountToTransfer);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber50 = await transferFromBankToContract.wait(3);
  await log(transferFromBankToContract, blockNumber50.blockNumber);
  console.log(blockNumber50.blockNumber);
  console.log(``);  

  await sleep(3000);

  console.log("(51) Customer 4 transfers 100 $ in CBMT Tokens (USD) to Customer 1's General address"); 
  const transferToGeneral_5 = await CBMT_Contract.connect(customer4General).safeTransferFrom(customer4General.address, customer1General.address, bank1TokenIdUSD, amountToTransfer, label);
  console.log(``);
  console.log("Transfer initiated, awaiting confirmation...");
  const blockNumber51 = await transferToGeneral_5.wait(3);
  await log(transferToGeneral_5, blockNumber51.blockNumber);
  console.log(blockNumber51.blockNumber);
  console.log(``);

  console.log(``);
  console.log("Script executed successfully ✔");
};

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function log(tx, blockNumber) {
  const base = process.env["CBMT_EXPLORER_URL"] || "https://explorer.evan.network/";
  
  const message = `${base}/tx/${tx.hash}`;

  console.log("You can see the tx status:" + message);
  
  try {
    await fs.appendFile('transaction-hash.txt', message + " " + blockNumber + '\n');
  } catch (err) {
    console.error('Error writing to file', err);
  }
} 

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });