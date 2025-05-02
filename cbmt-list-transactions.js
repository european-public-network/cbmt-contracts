const { ethers } = require ('ethers');
const { CBMTcontractAbi } = require('../backend/event-listener/config/CBMT_abi');
const { GeneralCBMTcontractAbi } = require('../backend/event-listener/config/GeneralCBMT_abi');

require("dotenv").config();

const providerUrl = process.env.RPC_URL || 'https://core.evan.network';
const provider = new ethers.providers.JsonRpcProvider( providerUrl );

const signerGeneralAddress = new ethers.Wallet(process.env.PRIVATE_KEY_GENERAL || process.env.PRIVATE_KEY, provider);

const CBMT_contractAddress = process.env.CBMT_CONTRACT_ADDRESS || process.env.CBMT_EPN;
const GeneralCBMT_contractAddress = process.env.GENERAL_CONTRACT_ADDRESS || process.env.GENERAL_CBMT_EPN;

//const CBMT_contract = new ethers.Contract( CBMT_contractAddress, CBMTcontractAbi, provider );
const iCBMT = new ethers.utils.Interface(CBMTcontractAbi);
const GeneralCBMT_contract = new ethers.Contract( GeneralCBMT_contractAddress, GeneralCBMTcontractAbi, provider );
const TransferTokenFromSupportedIssuer = 'TransferTokenFromSupportedIssuer';
const TransferTokenFromNotSupportedIssuer = 'TransferTokenFromNotSupportedIssuer';

let [ program, bankId, rangeSpecFrom, rangeSpecTo ] = process.argv;
if( ! rangeSpecTo) {
	rangeSpecTo = new Date().toISOString();
}

// XXX convert this into a parser that also understands Q1 , H1

function parseDate(date) {
	let m;
	if( m = /(\d\d\d\d)-?(\d\d)-?(\d\d)/.exec(date)) {
		return new Date( parseInt(m[1],10), parseInt(m[2], 10)-1, parseInt(m[3],10))

	} else {
		console.log("Could not parse '%s' as date", date)
		process.exit(-1)
    }
}

let dateTo = parseDate( rangeSpecTo );

if( ! rangeSpecFrom) {
	// There is no day shorter than 12 hours so this gets us the date of one day before
	rangeSpecFrom = new Date(dateTo.getTime()-3600*12).toISOString();
}
let dateFrom = parseDate( rangeSpecFrom );

//console.log(dateFrom.toDateString());
//console.log(dateFrom.getTimezoneOffset());
//console.log(dateTo.toDateString());

// We should have a cache of time -> blockNumber, and also do a binary search here instead of a linear scan
async function fetchEvents( from, to, { startBlockNum, maxBlockCount, maxTxCount, address } = {} ) {
	let res = [];
	
	const {currentBlock, highestBlock} = await provider.send('eth_syncing');
	if(currentBlock < highestBlock) {
		console.log('Warning! Node is not synced...\n');
	}

	let blockNum = startBlockNum || await provider.getBlockNumber();
	let fromTS = Math.floor(from.getTime()/1000);
	let toTS = Math.floor(to.getTime()/1000);
	let blocksToGo = maxBlockCount || -1;

	while(true) {
		const block = await provider.getBlockWithTransactions(blockNum--);
		//console.log("Block number: ", block.number, block.hash, blocksToGo, fromTS, toTS);

		if( blocksToGo != -1 ) {
			if( 0 == blocksToGo-- ) break;			
		}

		// Transaction is too late
		if(block.timestamp > toTS) continue;
		// Transaction is too early, we are done
		if(block.timestamp < fromTS) break;

		// Skip empty transactions
		if( 0 === block.transactions.length ) continue;
		
		let tx = block.transactions;
		// Filter the transactions for events of the CBMT contract
		if( address ) {
			tx = tx.filter((e,i,a) => { return e.to == address });
		};
		
		for (t of tx) {
			const r = await provider.getTransactionReceipt(t.hash);
			for (l of r.logs) {
				let log = iCBMT.parseLog(l);
				let args = log.args;
				res.push({ name: log.name, ...args});
			}

		}
	}
	return res
}

(async () => {
	const tx = await fetchEvents( dateFrom, dateTo, { startBlockNum: 47493479+2, maxBlockCount:4, address: CBMT_contractAddress } );
	for(t of tx) {
		console.log(`${t.name};${t.from};${t.to};${t.id};${t.value}`);
	}
})();


function extractLastTwoDigits(num) {
    return Number(String(num).slice(-2));
}



