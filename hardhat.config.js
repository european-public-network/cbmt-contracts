require("@nomicfoundation/hardhat-verify");
require("@nomicfoundation/hardhat-ethers");
require("hardhat-deploy");
require("hardhat-deploy-ethers");
require("solidity-coverage");
require("@nomicfoundation/hardhat-chai-matchers");
require('@openzeppelin/hardhat-upgrades');
const fs = require('fs-extra');

let config_file = './.env';
// See if the user specified a different config file
// We handroll this because invoking things later from the task would not
// allow us to set up the stuff properly (?!)
for (let i=0; i<process.argv.length; i++) {
	let opt = process.argv[i];
	if( opt == '--as' ) {
		const envname = process.argv[i+1];
		process.argv.splice(i,2);
		process.env.ENVNAME = envname;
        config_file = `./credentials/.${envname}.env`;
        if(! fs.existsSync(config_file)) {
            console.error(`File ${config_file} does not exist`);
            process.exit(-1);
        }
		console.log(`Running as ${envname} from ${config_file}`); // XXX make it respect silent mode
	}
}
require('dotenv').config({path: config_file});
require('dotenv').config({path: ".cbmt-contracts-test.env"});
require('dotenv').config({path: ".env"});

require( "./tasks/cbmt.js" );
require( "./tasks/dump-private-key.js" );
// Manually install a separately downloaded Solidity 0.8.28
const { TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD } = require("hardhat/builtin-tasks/task-names");
const path = require("path");

subtask(TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD, async (args, hre, runSuper) => {
  if (args.solcVersion === "0.8.28") {
    const compilerPath = path.join(__dirname, "solc-windows-amd64-v0.8.28+commit.7893614a.exe");

    return {
      compilerPath,
      //isSolcJs: true, // if you are using a native compiler, set this to false
      version: args.solcVersion,
      // this is used as extra information in the build-info files, but other than
      // that is not important
      longVersion: "0.8.5-nightly.2021.5.12+commit.98e2b4e5"
    }
  }

  // we just use the default subtask if the version is not 0.8.5
  return runSuper();
})


//console.log("Private key: ", process.env.PRIVATE_KEY);
module.exports = { 
  solidity:{ 
    version: "0.8.28", 
    settings: { 
      optimizer: { 
        enabled: true, 
        runs: 1
      }
    },
  },
  typechain: {
    dontOverrideCompile: true,
  },
  allowUnlimitedContractSize: true,
    networks: {
      ganache: {
        url: "http://127.0.0.1:8545", 
        gas: "auto", 
        gasLimit: 8000000000, 
      },
      evanNetwork:{
        //url: `https://core.evan.network`,
        url: `https://testcore.evan.network`,
        chainId: 508674158,
        accounts: [ process.env.PRIVATE_KEY ],
      }
    },
    defaultNetwork: "evanNetwork",
    //defaultNetwork: "ganache",
    namedAccounts: {
      owner: {
        default: 0,
        evanNetwork: "0x7Eb86Db47774782023e81c8c30E07b0fE81937c0"
      }
    },
};

// Clean up the accounts if we don't have a mnemonic available:
if( ! process.env.MNEMONIC ) {
    delete module.exports.networks.evanNetwork.accounts;
}
