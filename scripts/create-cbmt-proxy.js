// scripts/create-cbmt-with-proxy.js
"use strict";

const { ethers, upgrades } = require("hardhat");
const fs = require('fs-extra');
const dotenv = require('dotenv');

async function deployContract(name, initParams) {
  console.log(`deploying ${name} with uups Proxy`);
  console.log(initParams);
  const factory = await ethers.getContractFactory(name);
  const proxy = await upgrades.deployProxy(factory, initParams, {
      kind: "uups",
      // default anyway
      // initializer: "initialize"
  });
  return proxy.waitForDeployment();
}

async function upgradeContract(name, address) {
  console.log(`Upgrading ${name} with uups Proxy at ${address}`);
  const factory = await ethers.getContractFactory(name);
  const proxy = await upgrades.upgradeProxy(address, factory, {
      kind: "uups",
      // call: function_to_migrate_data
  });
  return proxy.waitForDeployment();
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

function updateConfigFile( fileName, content ) {
  const keys = Object.keys(content).sort();
  let newContent = "# Generated file, do not update manually";
  for( const k of keys ) {
      newContent = newContent + "\n" + `${k}="${content[k]}"`;
  }
  if( fs.existsSync(fileName)) {
      const oldContent = loadConfigFile(fileName);
      if( newContent !== oldContent ) {
          console.log(`Updating ${fileName}`);
          fs.writeFileSync(fileName, newContent);
      }
  } else {
      fs.writeFileSync(fileName, newContent);
  }
}

async function deployProxiedContract( owner, name, address, initParams, forceImplementationDeploy ) {
  const provider = hre.ethers.provider;
  let Contract;
  if( address ) {

    const Contract_f = await ethers.getContractFactory(name);
    const Contract_a = await( Contract_f.attach(address));
    Contract = await( Contract_a.connect(owner) );

    const currentImplAddress = await upgrades.erc1967.getImplementationAddress(await Contract.getAddress());
    console.log(`${name} proxy currently deployed to :`, await Contract.getAddress());
    console.log(`${name} current version             :`, await Contract.getContractVersion());

    let needsRedeploy = forceImplementationDeploy;
    if( ! needsRedeploy ) {
        // Check if we have a fresher/different version of the contract
        const artifact = await( loadJSONFile(`artifacts/contracts/${name}.sol/${name}.json`));
        const localByteCode = artifact.deployedBytecode;
        const deployedByteCode = await provider.getCode(currentImplAddress);

        // This check always fails since the deployed byte code differs from the local byte code, always
        needsRedeploy = (deployedByteCode != localByteCode);
        if( (deployedByteCode != localByteCode) ) {
            console.log("Deployed byte code length is different from local byte code");
        } else {
            console.log("Deployed byte code length is identical to local byte code, no redeploy needed");
        }
    }

    if( needsRedeploy ) {
        Contract = await upgradeContract(name, address);
        const currentImplAddress = await upgrades.erc1967.getImplementationAddress(await Contract.getAddress());
        console.log(`${name} version                   :`, await Contract.getContractVersion());
        console.log(`${name} implementation deployed to:`, currentImplAddress);
    }

  } else {
    Contract = await deployContract(name,initParams);
    const currentImplAddress = await upgrades.erc1967.getImplementationAddress(await Contract.getAddress());
    console.log(`${name} version                   :`, await Contract.getContractVersion());
    console.log(`${name} proxy          deployed to:`, await Contract.getAddress());
    console.log(`${name} implementation deployed to:`, currentImplAddress);
  }
  return Contract
}

async function deployContracts(owner, envFilename) {
  let deploymentInfo = await loadConfigFile(envFilename);

  /* Read previous deployment information from JSON file */

  const GeneralCBMT_address = deploymentInfo.GENERAL_CONTRACT_ADDRESS; // '0xA6E697fbA1DbF06b35F5B9ab8b1E514944c2B291';
  const forceImplementationDeploy = false;

  const GeneralCBMT_Contract = await deployProxiedContract(owner, 'GeneralCBMT', GeneralCBMT_address, [supportedCurrencies], forceImplementationDeploy);
  const currentImplAddress = await upgrades.erc1967.getImplementationAddress(await GeneralCBMT_Contract.getAddress());

  const name = deploymentInfo.CBMT_ENVIRONMENT_NAME || "CBMT Test";
  const explorerURL = deploymentInfo.CBMT_EXPLORER_URL || "https://testexplorer.evan.network/";
  const symbol = deploymentInfo.CBMT_SYMBOL || "CBMT";
  const baseURI = deploymentInfo.CBMT_SCHEMA_URL || "https://cbmt.world/schema/{id}/info.json";
  const RPC_URL = deploymentInfo.RPC_URL || "https://testcore.evan.network/";

  const CBMT_address = deploymentInfo.CBMT_CONTRACT_ADDRESS; // '0xa61a50de4086B03781B8707fDb7a0F5F379dE6e7';
  const CBMT_Contract = await deployProxiedContract(owner, 'CBMT', CBMT_address, [name, symbol, GeneralCBMT_address, baseURI], forceImplementationDeploy);


  // Save all information into .env file
  updateConfigFile( envFilename, {
      ...deploymentInfo,
      CBMT_ENVIRONMENT_NAME   : name,
      CBMT_EXPLORER_URL       : explorerURL,
      GENERAL_CONTRACT_ADDRESS: await GeneralCBMT_Contract.getAddress(),
      CBMT_CONTRACT_ADDRESS   : await CBMT_Contract.getAddress(),
      //CBMT_ESCROW_ADDRESS     : EscrowCBMT_Contract_Address,
      RPC_URL                 : RPC_URL
  });
  
  return { GeneralCBMT_Contract, CBMT_Contract, Escrow_Contract: undefined }
}

const supportedCurrencies = [978, 840];
const EUR_ID = supportedCurrencies[0];
const USD_ID = supportedCurrencies[1];

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
  
  const { GeneralCBMT_Contract, CBMT_Contract, Escrow_Contract } = await deployContracts( owner, envFilename );
}

main();