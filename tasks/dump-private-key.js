/*
Add to hardhat.config.js

    import( "./tasks/dump-private-key.js" );

Run as

    # dump the default key for the first keypair
    hardhat dump-private-key --network evanNetwork --as foo --index ...
	
	# dump a specific derivation path
    hardhat run dump-private-key --network --as foo m/44'/60'/0'/0/42

*/

import("@nomicfoundation/hardhat-toolbox"); // for the task() and scope() helper
const { Wallet } = require('ethers');

async function dump_private_key({derivation="m/44'/60'/0'/0/0"} = {}, hre, callSuper) {
	console.log(`Dumping private key for ${derivation}`);
	const wallet = Wallet.fromMnemonic(process.env.MNEMONIC, derivation);
	const pk = wallet.privateKey.slice(2);
	console.log(pk);
}

const cfg = require("hardhat/config");

cfg.task("dump-private-keys", "[Any] Dump a specific keypair for transitioning from mnemonic to address keypairs")
  .addOptionalParam("as", "The config file to load")
  .addOptionalParam("derivation", "The derivation path of the address")
  .setAction(dump_private_key);
