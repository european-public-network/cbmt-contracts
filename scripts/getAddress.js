const { ethers } = require("ethers");
async function getAddressFromMnemonic(mnemonic) {    
    try {
    const wallet = ethers.Wallet.fromMnemonic(mnemonic);
    const address = wallet.address;
    return address;
} catch (error) {        
    console.error("Error generating address:", error);
    throw error;    }
}
// Esempio di uso
const mnemonic = "barely awkward lucky result gospel under clown angle include jewel outer smart";
getAddressFromMnemonic(mnemonic).then(address => {
    console.log("First address associated to the mnemonic is:", address);})
    .catch(error => {
    console.error("Errore:", error);
});