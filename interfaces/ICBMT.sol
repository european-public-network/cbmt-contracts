// SPDX-License-Identifier: MIT 
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface ICBMT is IERC1155 {

    /// @dev Events declaration

    /** 
    * @dev Emitted when a bank requests to the TSP to receives blank tokens
    *
    */
    event RequestBlankToken( address bankRequester, uint256 currencyId, uint256 amount);

    /** 
    * @dev Emitted when Bank's mintAddress mints/stamps new CBMT tokens
    *
    */
    event StampToken( address bankRequester, uint256 tokenId, uint256 amount, bytes label);

    /** 
    * @dev Emitted when a bank demints CBMT tokens
    *
    */
    event DemintToken( address bankRequester, uint256 tokenId, uint256 amount);

    /** 
    * @dev Emitted when TSP burns blank tokens
    *
    */
    event BurnBlankToken( address bankRequester, uint256 currencyId, uint256 amount);

    /** 
    * @dev Emitted when an amount of tokens are transferred from a whitelisted customer to a whitelisted customer who supports same issuer
    *
    */
    event TransferTokenFromSupportedIssuer( address from, uint256 bankId, address to, uint256 tokenId, uint256 amountToTransfer);

    /** 
    * @dev Emitted when an amount of tokens are transferred from a whitelisted customer to a whitelisted customer who doesn't supports same issuer
    *
    */
    event TransferTokenFromNotSupportedIssuer( address from, uint256 bankId, address to, uint256 tokenId, uint256 amountToTransfer );

    /** 
    * @dev Emitted when an amount of tokens are transferred from the Bank to a whitelisted customer
    *
    */
    event TransferTokenToCustomer(address indexed from, address indexed to, uint256 bankId, uint256 tokenId, uint256 amountToTransfer);

    /** 
    * @dev Emitted when an amount of tokens are transferred from a Bank
    *
    */
    event TransferTokenFromBank( address from, address to, uint256 bankId, uint256 tokenId, uint256 amountToTransfer );
    
    /** 
    * @dev Emitted when an amount of tokens are transferred to a customer General Address
    *
    */
    event TransferTokenToGeneralAddress( address from, address to, uint256 bankId, uint256 tokenId, uint256 currencyId, uint256 amountToTransfer );

    /** 
    * @dev Emitted when an amount of tokens are transferred to a customer and doens't need conversion
    *
    */
    event TransferTokenSupportedIssuerAndCurrency( address from, address customerGeneralAddress, uint256 bankId, uint256 tokenId, uint256 currencyId, uint256 amountToTransfer );

    /** 
    * @dev Emitted when an amount of tokens are transferred to a customer and conversion is needed
    *
    */
    event TransferTokenToConvertAddress( address from, address to, uint256 bankId, uint256 tokenId, uint256 currencyId, uint256 amountToTransfer );

    /** 
    * @dev Emitted when after a transfer a currency conversion is needed
    *
    */
    event ConvertFromSupportedIssuerNotCurrency( address customerConvertAddress, address bankGeneralAddress, address customerGeneralAddress, uint256 bankId, uint256 tokenId, uint256 newTokenId, uint256 amountToConvert, uint256 amountToExchange );

    /** 
    * @dev Emitted when after a transfer an issuer conversion is needed
    *
    */
    event ConvertFromNotSupportedIssuer( address from, address customerConvertAddress, address bankGeneralAddress, address customerGeneralAddress, uint256 bankId, uint256 tokenId, uint256 newTokenId, uint256 currencyId, uint256 amountToConvert );

    /** 
    * @dev Emitted when after a transfer an issuer and currency conversion are needed
    *
    */
    event ConvertFromNotSupportedIssuerAndCurrency( address bankGeneralAddress, address customerConvertAddress, address customerGeneralAddress, uint256 tokenId, uint256 newTokenId, uint256 amountToConvert, uint256 amountToExchange );

    /** 
    * @dev Emitted when a net settlement is completed
    *
    */
    event NetSettlement( address fromBankGeneralAddress , address toBankGeneralAddress, uint256 fromBankId, uint256 toBankId, uint256 tokenId_1, uint256 tokenId_2, uint256 currencyId, uint256 tokenThatWantToBeSettled );

    /** 
    * @dev Emitted when an amount of tokens are forwarded to the customer generalAddress without conversion
    *
    */
    event ConvertForSupportedIssuerAndCurrency( address customerConvertAddress, address customerGeneralAddress, uint256 tokenId, uint256 amountToConvert );

    /** 
    * @dev Emitted when an amount of tokens are converted to the new currency and forwarded to the customer generalAddress 
    *
    */
    event ConvertForNotSupportedCurrency( address mintAddress, address customerGeneralAddress, uint256 newTokenId, uint256 amountToExchange );

    /** 
    * @dev Emitted when an amount of tokens are converted to the new bank tokens and forwarded to the customer generalAddress 
    *
    */
    event ConvertForNotSupportedIssuer( address mintAddress, address customerGeneralAddress, uint256 newTokenId, uint256 amountToConvert );

    /** 
    * @dev Emitted when an amount of tokens are converted to the new bank tokens and currency and forwarded to the customer generalAddress 
    *
    */
    event ConvertForNotSupportedIssuerAndCurrency( address mintAddress, address customerGeneralAddress, uint256 tokenId, uint256 amountToExchange );

    /** 
    * @dev Emitted when an amount of tokens are transferred from customer to Bank's redemptionAddress 
    *
    */
    event ReturnTokens( address customerAddress, address redemptionAddress, uint256 bankId, uint256 tokenId, uint256 currencyId, uint256 amountToReturn);

    /** 
    * @dev Emitted when a Bank start a net Settlement 
    *
    */
    event StartNetSettlement(uint256 fromBankId, uint256 toBankId, uint256 currencyId, uint256 amountToSettle);

    /** 
    * @dev Emitted when a Bank does a gross Settlement 
    *
    */
    event GrossSettlement( address generalAddress, address redemptionAddress, uint256 fromBankId, uint256 toBankId, uint256 currencyId, uint256 amountSettled);

    /** 
    * @dev Return a string indicating the URI setted by a Bank at the moment of the token's deploy 
    *
    */ 
    function getUri(uint256 tokenId) external view returns (string memory);

    /** 
    * @dev Return a string indicating the name setted by TSP at the moment of the contract's deploy 
    *
    */
    function getName() external view returns (string memory);

    /** 
    * @dev Return a string indicating the symbol setted by TSP at the moment of the contract's deploy 
    *
    */
    function getSymbol() external view returns (string memory);

    /** 
    * @dev Function called by Bank's issuingAddress to instruct TSP to mine blank tokens 
    *
    * Emits a {RequestBlankToken} event.
    */ 
    function requestBlankToken( uint256 bankId, uint256 currencyId, uint256 amount ) external;

    /** 
    * @dev Function called by Bank's mintAddress to mint/stamp (converting blank tokens into CBMT) CBMT tokens 
    *
    * Emits a {StampToken} event.
    */ 
    function stampToken( uint256 bankId, uint256 currencyId, uint256 amount, bytes memory label ) external;

    /** 
    * @dev Function called by a Bank's issuingAddress to demint (converting CBMT to blank) CBMT tokens
    *
    * Emits a {DemintToken} event.
    */ 
    function demintToken( uint256 bankId, uint256 currencyId, uint256 amount ) external;

    /** 
    * @dev Function called by a Bank's issuingAddress to burn blank tokens
    *
    * Emits a {BurnBlankToken} event.
    */ 
    function burnBlankToken( uint256 bankId, uint256 currencyId, uint256 amount ) external;

    /** 
    * @dev Function called by a bank to transfer CBMT tokens to another address
    *
    */ 
    function transfer( uint256 bankId, address to, uint256 tokenId, uint256 amountToTransfer) external;

    /** 
    * @dev Function called by Mint Address to send bank token to the customer
    */ 
    function requestTokenFromCustomer( uint256 bankId, address customerGeneralAddress, uint256 currencyId, uint256 amountToTransfer ) external;

    /** 
    * @dev Function called by Backend when it listens transfer event for supported issuer
    *
    * Emits a {ConvertForSupportedIssuerAndCurrency or ConvertForNotSupportedCurrency} event.
    */ 
    function convertTokenFromSupportedIssuer(uint256 tokenId, uint256 bankId, uint256 currencyId, uint256 amountToConvert, address customerConvertAddress ) external;

    /** 
    * @dev Function called by Backend when it listens transfer event for non supported issuer
    *
    * Emits a {ConvertForNotSupportedIssuer or ConvertForNotSupportedIssuerAndCurrency} event.
    */ 
    function convertTokenFromNotSupportedIssuer( uint256 tokenId, uint256 bankId, uint256 currencyId, uint256 amountToConvert, address customerConvertAddress ) external;

    /** 
    * @dev Function called by a customer to return/transfer in-house tokens to the Bank's redemptionAddress
    *
    * Emits a {ReturnTokens} event.
    */ 
    function returnTokens( uint256 bankId, uint256 currencyId, uint256 amountToReturn ) external;

    /** 
    * @dev Function called by a Bank's General Address to open a request of bilateral net settlement with another Bank
    *
    * Emits a {StartNetSettlement} event.
    */ 
    function startNetSettlement(uint256 fromBankId, uint256 toBankId, uint256 currencyId, uint256 amountToSettle) external;

    /** 
    * @dev Function called by the Bank's General Address which receive the request of bilateral net settlement 
    *
    * Emits a {AcceptNetSettlement} event.
    */ 
    function acceptNetSettlement(uint256 toBankId, uint256 fromBankId) external;

    /** 
    * @dev Function called by the Bank's general address to carry out gross settlement
    *
    * Emits a {GrossSettlement} event.
    */ 
    function grossSettlement( uint256 fromBankId, uint256 toBankId, uint256 currencyId, uint256 amountToSettle) external;

    /**
    * @dev Bank can set the exchange rate for a currency pair
    *
    */
    function setExchangeRate( uint256 bankId, uint256 fromCurrencyId_1, uint256 toCurrencyId_2, uint256 exchangeRate ) external;

    /** 
    * @dev Returns a boolean value indicating if the address is a Bank's issuingAddress  
    *
    */ 
    function isIssuingAddress(uint256 tokenId, address issuingAddress) external view returns (bool);

    /** 
    * @dev Returns a boolean value indicating if the address is a Bank's mintAddress  
    *
    */ 
    function isMintAddress(uint256 tokenId, address mintAddress) external view returns (bool);

    /** 
    * @dev Returns a boolean value indicating if the address is a Bank's redemptionAddress  
    *
    */ 
    function isRedemptionAddress(uint256 tokenId, address redemptionAddress) external view returns (bool);

    /** 
    * @dev Returns a boolean value indicating if the address is a Bank's generalAddress  
    *
    */ 
    function isGeneralAddress(uint256 tokenId, address generalAddress) external view returns (bool);

    /** 
    * @dev Returns a value indicating the tokenId from the BankId
    *
    */ 
    function getTokenIdFromBankId(uint256 bankId, uint256 currencyId) external view returns (uint256);

    /** 
    * @dev Returns a value indicating the BankId from the tokenId
    *
    */ 
    function getBankIdFromTokenId(uint256 tokenId, uint256 currencyId) external pure  returns (uint256);

    /** 
    * @dev Returns a boolean value indicating if there is a pending net settlement between two banks
    *
    */ 
    function getNetSettlementAvailability(uint256 fromBankId, uint256 toBankId) external view returns (bool);

    /** 
    * @dev Returns a value indicating the currency for a pending net settlement
    *
    */ 
    function getNetCurrencyToSettle(uint256 fromBankId, uint256 toBankId) external view returns (uint256);

    /** 
    * @dev Returns a value indicating the amount to settle for a pending net settlement
    *
    */ 
    function getNetAmountToSettle(uint256 fromBankId, uint256 toBankId) external view returns (uint256);

    /**
    * @dev Get the bank exchange rate for a currency pair
    *
    */
    function getExchangeRate( uint256 bankId, uint256 fromCurrencyId_1, uint256 toCurrencyId_2  ) external view returns(uint256);
}
