// SPDX-License-Identifier: MIT 
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IGeneralCBMT {

    /** 
    * @dev Struct indicating all info related to a single Bank
    */ 
    struct Bank {
        address _issuingAddress;
        address _mintAddress;
        address _redemptionAddress;
        address _generalAddress;
        uint256 _bankId;
        string _name;
    }

    /**
    * @dev Struct indicating all info related to a single Customer
    */
    struct Customer {
        address _customerGeneralAddress;
        EnumerableSet.UintSet _supportedIssuers;
        uint256 _preferredCurrency;
    }

    /// @dev EVENTS DECLARATION

    /** 
    * @dev Emitted when a new currency is added to the consortium 
    */ 
    event AddCurrency(uint256 currencyId);

    /** 
    * @dev Emitted when a currency is removed from the consortium  
    */ 
    event RemoveCurrency(uint256 currencyId);

    /** 
    * @dev Emitted when one bank is added to the participating Banks 
    */ 
    event AddParticipatingBank(address issuingAddress, address mintAddress, address redemptionAddress, address generalAddress, uint256 bankId, string name);

    /** 
    * @dev Emitted when one bank is removed from the participating Banks 
    */ 
    event RemoveParticipatingBank(uint256 bankId, address issuingAddress, address mintAddress, address redemptionAddress, address generalAddress);

    /** 
    * @dev Emitted when one or more customers are added to the whitelist 
    */ 
    event AddToWhitelist( uint256 bankId, address customerAddress );

    /** 
    * @dev Emitted when a Bank create a new customer
    */ 
    event RegisterCustomer( uint256 bankId, address customerConvertAddress, address customerGeneralAddress );

    /** 
    * @dev Emitted when one or more customers are removed from the whitelist 
    */ 
    event RemoveFromWhitelist(uint256 bankId, address customerConvertAddress, address customerGeneralAddress);

    /** 
    * @dev Emitted when one or more customers is added to a Bank's blacklist 
    */ 
    event AddToBlacklist(uint256 bankId, address generalAddress);
 
    /** 
    * @dev Emitted when one or more currencies are added to a customer
    */ 
    event AddCurrencyToCustomer(uint256 bankId, address customerGeneralAddress, address customerConvertAddress, uint256[] currencyIds );

    /** 
    * @dev Emitted when one currency is removed from a customer 
    */ 
    event RemoveCurrencyFromCustomer(uint256 bankId, address customerGeneralAddress, address customerConvertAddress, uint256 currencyId );

    /** 
    * @dev Emitted when one or more customers is removed from a Bank's blacklist 
    */ 
    event RemoveFromBlacklist(uint256 bankId, address generalAddress);

    /** 
    * @dev Emitted when Customer add a bank to its supported issuers 
    */ 
    event AddCustomerSupportedIssuer( uint256 bankId, address customerConvertAddress, address customerGeneralAddress);   

    /** 
    * @dev Emitted when Customer removes a bank from supported issuers 
    */ 
    event RemoveCustomerSupportedIssuer( uint256 bankId, address customerConvertAddress, address customerGeneralAddress );

    /** 
    * @dev Emitted when a new general address is set for a customer
    */ 
    event SetNewGeneralAddress( uint256 bankId, address customerConvertAddress, address customerGeneralAddress, address oldGeneralAddress);

    /** 
    * @dev Emitted when an existing Bank's Token ID has been frozen
    */ 
    event FreezeTokenId(uint256 tokenId);

    /** 
    * @dev Emitted when a existing Bank's Token ID has been unfrozen
    */ 
    event UnfreezeTokenId(uint256 tokenId);

    /// @dev FUNCTIONS DECLARATION

    /** 
    * @dev Function called by TSP to add a currency to the contract
    *
    */
    function addCurrency(uint256 currencyId) external;

    /** 
    * @dev Function called by TSP to remove a currency from the contract
    *
    */
    function removeCurrency(uint256 currencyId) external;   

    /** 
    * @dev Function called by TSP to add a Bank with its four addresses and its token to the consortium
    *
    * Emits a {AddParticipatingBank} event.
    */ 
    function addParticipatingBank(address issuingAddress,
        address mintAddress,
        address redemptionAddress,
        address generalAddress,
        string memory name
        ) external;

    /** 
    * @dev Function called by TSP to remove a Bank with its four addresses and its token from the consortium
    *
    * Emits a {RemoveParticipatingBank} event.
    */ 
    function removeParticipatingBank(uint256 bankId) external;

    /** 
    * @dev Function called by TSP to add a customer to the whitelist.
    *
    * Emits a {AddToWhitelist} event.
    */ 
    function addToWhitelist(uint256 bankId, address customerAddress) external;
    
    /** 
    * @dev Function called from a converted address to register and be recognized as a customer
    * Emits a {RegisterCustomer} event.
    */ 
    function registerCustomer( uint256 bankId, address customerGeneralAddress ) external;

    /** 
    * @dev Function called by TSP to remove a customer from the whitelist.
    *
    * Emits a {RemoveFromWhitelist} event.
    */ 
    function removeFromWhitelist(uint256 bankId, address customerAddress) external;

    /** 
    * @dev Function called by a Bank to add to its own blacklist a customer 
    *
    * Emits a {AddToBlacklist} event.
    */ 
    function addToBlacklist(uint256 bankId, address customerAddress) external;

    /** 
    * @dev Function called by a Bank to remove from its own blacklist a customer
    *
    * Emits a {RemoveFromBlacklist} event. 
    */ 
    function removeFromBlacklist(uint256 bankId, address customerAddress) external;

    /** 
    * @dev Adds to the customer the IDs of the currencies it can support
    */ 
    function addCurrencyToCustomer( uint256 bankId, address customerConvertAddress, uint256[] memory currencyId ) external;

    /** 
    * @dev Remove from the customer the IDs of the currencies he no longer support
    */ 
    function removeCurrencyFromCustomer( uint256 bankId, address customerConvertAddress, uint256 currencyId ) external ;

    /** 
    * @dev Add new supported issuer to the customer
    */ 
    function addCustomerSupportedIssuer( uint256 bankId ) external;

    /** 
    * @dev Remove new supported issuer from the customer
    */ 
    function removeCustomerSupportedIssuer( uint256 bankId ) external;

    /** 
    * @dev Associate a new whitelisted general address to the convert address
    */ 
    function setNewGeneralAddress( address customerGeneralAddress ) external;

    /** 
    * @dev Set the general preferred currency for the customer
    */ 
    function setCustomerPreferredCurrency( uint256 currencyId ) external;

    /** 
    * @dev Set the designated Issuer that will perform the convert for a specific currency
    */ 
    function setCustomerPreferredIssuerForCurrency( uint256 currencyId, uint256 bankId ) external;

    /** 
    * @dev Function called by a convert address to disable itself and no longer be recognized as a convert address
    */ 
    function disableConvertAddress() external;

    /** 
    * @dev Function called from a disabled convert address to re-enable itself and be recognized as a convert address again
    */ 
    function enableConvertAddress(address customerConvertAddress) external;

    /** 
    * @dev Function called by TSP to freeze/pause an existing Bank's Token ID
    *
    * Emits a {FreezeTokenId} event.
    */  
    function freezeTokenId( uint256 tokenId) external;

    /**
    * @dev Function called by TSP to unfreeze/unpause an existing Bank's Token ID from the frozen one
    *
    * Emits a {UnfreezeTokenId} event.
    */  
    function unfreezeTokenId( uint256 tokenId) external;

    /** 
    * @dev Returns a boolean value indicating customer's whitelist status.
    */ 
    function isWhitelisted(address customerAddress) external view returns (bool);

    /** 
    * @dev Check if the customer general address is whitelisted for the specified bank
    */ 
    function isBankCustomerWhitelisted( address customerGeneralAddress, uint256 bankId ) external view  returns ( bool );

    /** 
    * @dev Returns a boolean value indicating the blacklist status of a customer 
    */ 
    function isBlacklisted(uint256 bankId, address customerAddress) external view returns (bool);

    /** 
    * @dev Returns a boolean value indicating if the address is a customer General Address
    */ 
    function isCustomerGeneralAddress( address customerGeneralAddress ) external view returns ( bool );

    /** 
    * @dev Returns a boolean value indicating if the address is a Customer Convert address
    */ 
    function isCustomerConvertAddress(address customerAddress) external view returns (bool);

    /** 
    * @dev Returns a boolean value indicating validity status of currency 
    *
    */
    function isValidCurrency(uint256 currencyId) external view returns (bool);

    /** 
    * @dev Returns a boolean value indicating validity status of a Bank's Token ID
    */  
    function isValidToken(uint256 tokenId) external view returns (bool);

    /** 
    * @dev Returns a boolean value indicating frozen status of a Bank's Token ID
    */  
    function isFrozenToken(uint256 tokenId) external view returns (bool);

    /** 
    * @dev Returns a Boolean value indicating whether the address belongs to a bank
    */  
    function isParticipatingBank( address bankAddress) external view returns (bool);

    /** 
    * @dev Check if the bank ID is a valid one
    */ 
    function isValidBank( uint256 bankId ) external view returns ( bool );

    /** 
    * @dev Check if customer's convert address supports a specified issuer (Bank)
    */ 
    function isCustomerSupportedIssuer( address customerConvertaddress, uint256 bankId ) external view returns (bool);
  
    /** 
    * @dev Check if customer's convert address supports a currency for a specified Bank
    */ 
    function isCustomerSupportedCurrency( uint256 bankId, address customerConvertAddress, uint256 currencyId ) external view returns (bool);

    /** 
    * @dev Returns a integer value indicating the id that will be assigned to next partecipating bank
    */ 
    function getCurrentBankId( ) external view returns (uint256);

    /** 
    * @dev Returns an address indicating issuing addresses related to the provided BankId
    */ 
    function getIssuingAddress(uint256 bankId) external view returns (address);

    /** 
    * @dev Returns an address indicating mint addresses related to the provided BankId
    */ 
    function getMintAddress(uint256 bankId) external view returns (address);

    /** 
    * @dev Returns an address indicating redemption addresses related to the provided BankId
    */ 
    function getRedemptionAddress(uint256 bankId) external view returns (address);

    /** 
    * @dev Returns an address indicating general addresses related to the provided BankId
    */ 
    function getGeneralAddress(uint256 bankId) external view returns (address);

    /** 
    * @dev Returns a string indicating the name related to the provided BankId
    */ 
    function getBankName(uint256 bankId) external view returns (string memory);

    /** 
    * @dev Returns all the supported currencies
    *
    */
    function getCurrencies() external view returns (uint[] memory);

    /** 
    * @dev Returns an array of structures indicating all participating Banks
    */ 
    function getParticipatingBanks() external view returns(Bank[] memory);

    /** 
    * @dev Returns a struct indicating all the info related to a Bank Token ID
    */ 
    function getParticipatingBank(uint256 tokenId) external view returns(Bank memory);

        /** 
    * @dev Returns the customer General Address associated with the customer's Convert Address
    */ 
    function getCustomerGeneralAddress( address customerConvertAddress ) external view returns (address);
    
    /** 
    * @dev Retrieves all banks that have whitelisted a customer's general address
    */ 
    function getBankThatWhitelistedCustomer(address customerGeneralAddress) external view returns (uint[] memory);
    
   /** 
    * @dev Returns an array containing the customer's supported issuer
    */ 
    function getCustomerSupportedIssuer( address customerConvertAddress ) external view  returns ( uint256[] memory );

    /** 
    * @dev Get the customer convert address related to the general
    */ 
    function getCustomerConvertAddressFromGeneralAndBankId( address customerGeneralAddress, uint256 bankId ) external view returns (address[] memory);

    /** 
    * @dev Returns the ID of the designated Issuer that will perform the convert for a specific currency
    */ 
    function getCustomerPreferredIssuerForCurrency( address customerConvertAddress, uint256 currencyId ) external view returns(uint256);

    /** 
    * @dev Returns the ID of the preferred currency associated with the customer's Convert Address
    */ 
    function getCustomerPreferredCurrency( address customerConvertAddress ) external view  returns (uint256);
}
