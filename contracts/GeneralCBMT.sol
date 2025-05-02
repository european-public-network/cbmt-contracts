// SPDX-License-Identifier: MIT  
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IGeneralCBMT.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract GeneralCBMT is Initializable, IGeneralCBMT, OwnableUpgradeable, UUPSUpgradeable {

    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant BANK_ID_ADDER = 1000;
    uint256 public bank_Id;
    
    mapping( uint256 => Bank ) internal _bank;
    mapping( address => Customer ) internal _customer;
    mapping( uint256 => bool ) internal _frozenToken;
    mapping( address => mapping (uint256 => EnumerableSet.AddressSet) ) internal _customerConvertFromGeneralAndBankId;
    mapping( address => bool ) internal _isCustomerGeneralAddress;
    mapping( address => bool ) internal _isCustomerConvertAddress;

    mapping( address => EnumerableSet.UintSet ) internal _customerToBankThatWhitelistedHim;
    mapping( uint256 => EnumerableSet.AddressSet ) internal _supportedIssuerToConvert;

    mapping( uint256 => EnumerableSet.AddressSet ) internal _bankToWhitelistedCustomer;
    mapping( uint256 => EnumerableSet.AddressSet) internal _bankToBlacklistedCustomer;
    
    mapping( uint256 => mapping ( address => EnumerableSet.UintSet) ) internal _supportedCurrencies;
    mapping( address => mapping ( uint256 => uint256 ) ) internal _preferredIssuerForCurrency;

    EnumerableSet.AddressSet internal participatingBanks;
    EnumerableSet.UintSet private currencies;
    EnumerableSet.UintSet private _validTokenIds;
    
    function initialize(uint256[] memory initialCurrencies) public initializer {
        __Ownable_init(msg.sender);
        bank_Id = 1000;
        for (uint256 i = 0; i < initialCurrencies.length; i++) {
            currencies.add(initialCurrencies[i]);
        }
    }

    function getContractVersion() public pure returns (uint256) {
        return 20250313000101; /* CBMTContractVersion */
    }

    modifier onlyParticipatingBank(uint256 bankId) {
        require(getIssuingAddress(bankId) == msg.sender || getMintAddress(bankId) == msg.sender 
                || getRedemptionAddress(bankId) == msg.sender || getGeneralAddress(bankId) == msg.sender,
                "Only Participating Bank can perform this action");
        _;
    }

    modifier onlyWhitelisted(uint256 bankId) {
        require( isBankCustomerWhitelisted(msg.sender, bankId), "Only whitelisted customer can call this function" );
        _;
    }

    modifier onlyConvertAddress() {
        require( isCustomerConvertAddress(msg.sender), "Only Convert Address can call this function" );
        _;
    }
    
    function addCurrency(uint256 currencyId) public override onlyOwner{
        require( !currencies.contains(currencyId), "Currency already exists");
        // CHG002  require( currencyId > 0 && currencyId < 100, "Currency ID must be between 0 and 99");
        require( currencyId > 99 && currencyId < 1000, "Currency ID must be between 100 and 999");
        currencies.add(currencyId);
        
        emit AddCurrency(currencyId);
    }

    function removeCurrency(uint256 currencyId) public override onlyOwner{
        require(currencies.contains(currencyId), "Currency does not exist");
        currencies.remove(currencyId);

        emit RemoveCurrency(currencyId);
    }

    function addParticipatingBank(address issuingAddress, address mintAddress, address redemptionAddress, address generalAddress, string memory name ) public override onlyOwner {
        require(!isParticipatingBank(issuingAddress) && !isParticipatingBank(mintAddress) && !isParticipatingBank(redemptionAddress) && !isParticipatingBank(generalAddress), "Bank already exists");
        
        uint256 newBankId = bank_Id;
        bank_Id += BANK_ID_ADDER;
        
        _bank[newBankId] = Bank({
            _issuingAddress: issuingAddress,
            _mintAddress: mintAddress,
            _redemptionAddress: redemptionAddress,
            _generalAddress: generalAddress,
            _bankId: newBankId,
            _name: name
        });

        participatingBanks.add(issuingAddress);
        participatingBanks.add(mintAddress);
        participatingBanks.add(redemptionAddress);
        participatingBanks.add(generalAddress);

        //Add all tokenIds for this new bank to the valid ones
        
        for(uint256 i = 0; i < currencies.length() ; i++ ){
            // CHG002   _validTokenIds.add(newBankId + i);
            _validTokenIds.add(newBankId + currencies.at(i));
        }

        emit AddParticipatingBank(issuingAddress, mintAddress, redemptionAddress, generalAddress, newBankId, name);
    }

    function removeParticipatingBank( uint256 bankId ) public override onlyOwner {

        address issuingAddress = getIssuingAddress(bankId);
        address mintAddress = getMintAddress(bankId);
        address redemptionAddress = getRedemptionAddress(bankId);
        address generalAddress = getGeneralAddress(bankId);

        require(isParticipatingBank(issuingAddress) && isParticipatingBank(mintAddress) && isParticipatingBank(redemptionAddress) && isParticipatingBank(generalAddress), "Bank doesn't exists");

        address[] memory customers = getBankCustomers(bankId);

        for(uint256 i = 0; i < customers.length; i++ ){
            
            address[] memory customerConvertAddress = getCustomerConvertAddressFromGeneralAndBankId(customers[i], bankId);
            
            for(uint256 k = 0; k < customerConvertAddress.length; k++ ){
                _customer[ customerConvertAddress[k] ]._supportedIssuers.remove( bankId );
            }
            
            _customerToBankThatWhitelistedHim[customers[i]].remove(bankId);

            if( _customerToBankThatWhitelistedHim[customers[i]].length() == 0 ){

                _isCustomerGeneralAddress[customers[i]] = false;
                 
                for( uint256 j = 0; j < customerConvertAddress.length; j++){

                    _isCustomerConvertAddress[customerConvertAddress[j]] = false;
                    _customerConvertFromGeneralAndBankId[customers[i]][bankId].remove(customerConvertAddress[j]);
                }
            }
        }
        
        address[] memory convertAddresses = getConvertSupportedIssuer(bankId);

        for(uint256 i = 0; i < convertAddresses.length; i++ ){
            _customer[ convertAddresses[ i ] ]._supportedIssuers.remove(bankId);
        }

        
        delete _bank[bankId]._issuingAddress;
        delete _bank[bankId]._mintAddress;
        delete _bank[bankId]._redemptionAddress;
        delete _bank[bankId]._generalAddress;
        delete _bank[bankId]._bankId;
        delete _bank[bankId]._name;
        
        participatingBanks.remove(issuingAddress);
        participatingBanks.remove(mintAddress);
        participatingBanks.remove(redemptionAddress);
        participatingBanks.remove(generalAddress);

        //Remove all tokenIds for this new bank from the valid ones
        // CHG 002  create list of valid currencies necessary
        // for(uint256 i = 0; i < currencies.length(); i++ ){
        //  _validTokenIds.remove(bankId + i);
        
        for(uint256 i = 0; i < currencies.length(); i++ ){
            _validTokenIds.remove(bankId + currencies.at(i));
        }

        emit RemoveParticipatingBank(bankId ,issuingAddress, mintAddress, redemptionAddress, generalAddress);
    }

    function addToWhitelist( uint256 bankId, address customerGeneralAddress ) public override onlyParticipatingBank(bankId) {

        require ( !isBlacklisted( bankId, customerGeneralAddress ), "Customer General Address must not be blacklisted");
        require ( !isBankCustomerWhitelisted(customerGeneralAddress, bankId), "This address is already whitelisted from this bank" );
        require ( !isCustomerConvertAddress(customerGeneralAddress), "You cannot whitelist convert address");
        
        _bankToWhitelistedCustomer[bankId].add(customerGeneralAddress);
        _customerToBankThatWhitelistedHim[customerGeneralAddress].add(bankId);
        _isCustomerGeneralAddress[customerGeneralAddress] = true;
        
        emit AddToWhitelist( bankId, customerGeneralAddress );
    }

    function registerCustomer( uint256 bankId, address customerGeneralAddress ) public override {

        require( isBankCustomerWhitelisted(customerGeneralAddress, bankId), "Provided General Address is not whitelisted" );
        require ( msg.sender != customerGeneralAddress, "Caller cannot be a General Address" );

        require( _customer[msg.sender]._customerGeneralAddress == address(0x0), "Caller is already registered" );
    
        _customer[msg.sender]._customerGeneralAddress = customerGeneralAddress;
        _customer[msg.sender]._supportedIssuers.add(bankId);
        _customer[msg.sender]._preferredCurrency = 0;
        _preferredIssuerForCurrency[ msg.sender ][ 0 ] = bankId;
        _supportedCurrencies[ bankId ][ msg.sender ].add(0);
        
        _customerConvertFromGeneralAndBankId[customerGeneralAddress][bankId].add(msg.sender);
        
        _isCustomerConvertAddress[msg.sender] = true;

        emit RegisterCustomer( bankId, msg.sender, customerGeneralAddress );
    }

    function removeFromWhitelist( uint256 bankId, address customerGeneralAddress ) public override onlyParticipatingBank(bankId) {
        require ( isBankCustomerWhitelisted( customerGeneralAddress, bankId ), "This address is not your customer" );
        _customerToBankThatWhitelistedHim[customerGeneralAddress].remove(bankId);
        address[] memory customerConvertAddress = getCustomerConvertAddressFromGeneralAndBankId(customerGeneralAddress, bankId);
        
        //Remove selected bankId from the supportedIssuer for this customer
        
        for( uint256 i = 0; i < customerConvertAddress.length; i++ ){  
            _customer[customerConvertAddress[i]]._supportedIssuers.remove( bankId );
            uint256[] memory supportedCurrencies = getSupportedCurrencies( bankId, customerConvertAddress[i] ); 
            
            for( uint256 j = 0; j < supportedCurrencies.length; j++ ){ 
                _supportedCurrencies[ bankId ][ customerConvertAddress[i] ].remove( supportedCurrencies[j] ); 
                
                if( isCustomerPreferredIssuerForCurrency( customerConvertAddress[i], supportedCurrencies[j], bankId) ){ 
                    _preferredIssuerForCurrency[ customerConvertAddress[i] ][ supportedCurrencies[j] ] = 0; 
                    uint256[] memory supportedIssuers = getCustomerSupportedIssuer( customerConvertAddress[i] );
                    
                    if( supportedIssuers.length > 0 ) {
                        
                        for( uint256 k = 0; k < supportedIssuers.length; k++ ){
                            if( isWhitelisted( customerGeneralAddress ) ) {
                                if(isCustomerSupportedCurrency( supportedIssuers[k], customerConvertAddress[i], supportedCurrencies[j] )) {
                                    _preferredIssuerForCurrency[ customerConvertAddress[i] ][ supportedCurrencies[j] ] = supportedIssuers[k];
                                }  
                            } else _customer[customerConvertAddress[i]]._supportedIssuers.remove( supportedIssuers[k] );                          
                        }
                    }
                }

                if( getCustomerPreferredCurrency(customerConvertAddress[i]) == supportedCurrencies[j]){ 
            
                    uint256[] memory supportedIssuers = getCustomerSupportedIssuer( customerConvertAddress[i] ); 
                    bool currencySupported = false;
                    for(uint256 z = 0; z < supportedIssuers.length; z++ ){
                        
                        if(isCustomerSupportedCurrency( supportedIssuers[z], customerConvertAddress[i], supportedCurrencies[j] )) {
                            currencySupported = true;
                            break;
                        } 
                    }
                    if(supportedIssuers.length > 0 && !currencySupported && EnumerableSet.length(_supportedCurrencies[ supportedIssuers[0] ][ customerConvertAddress[i] ]) != 0 ){
                        uint256[] memory availableCurrency = getSupportedCurrencies( supportedIssuers[0], customerConvertAddress[i] );
                        _customer[ customerConvertAddress[i] ]._preferredCurrency = availableCurrency[0];
                    }

                }
            }

            if( _customerToBankThatWhitelistedHim[customerGeneralAddress].length() == 0 ){
            
                _isCustomerGeneralAddress[customerGeneralAddress] = false;
                _isCustomerConvertAddress[customerConvertAddress[i]] = false;
                _customer[ customerConvertAddress[i] ]._preferredCurrency = 0;
                _customer[ customerConvertAddress[i] ]._customerGeneralAddress = address(0x0);
            }

            emit RemoveFromWhitelist( bankId, customerConvertAddress[i], customerGeneralAddress );
        }
    }

    function addToBlacklist(uint256 bankId, address customerGeneralAddress) public override onlyParticipatingBank(bankId) {
        require( !isBlacklisted( bankId, customerGeneralAddress ), "Customer already blacklisted" );
        
        _bankToBlacklistedCustomer[bankId].add( customerGeneralAddress );

        emit AddToBlacklist( bankId, customerGeneralAddress );
    }

    function removeFromBlacklist(uint256 bankId, address customerGeneralAddress ) public override onlyParticipatingBank(bankId){
        require( isBlacklisted( bankId, customerGeneralAddress), "Customer not blacklisted" );

        _bankToBlacklistedCustomer[bankId].remove( customerGeneralAddress );
        emit RemoveFromBlacklist( bankId, customerGeneralAddress );
    }

    function addCurrencyToCustomer( uint256 bankId, address customerConvertAddress, uint256[] memory currencyId ) public override onlyParticipatingBank(bankId) {
        address customerGeneralAddress = getCustomerGeneralAddress(customerConvertAddress);

        require( isWhitelisted( customerGeneralAddress ), "This convert address is not linked to a whitelisted general address");

        for(uint256 i = 0; i < currencyId.length; i++){
            require( isValidCurrency(currencyId[i]), "All currencies must be valid" );
            _supportedCurrencies[ bankId ][ customerConvertAddress ].add( currencyId[i] );
            
            if( getCustomerPreferredIssuerForCurrency(customerConvertAddress, currencyId[i] )  == 0 ){
                _preferredIssuerForCurrency[ customerConvertAddress ][ currencyId[i] ] = bankId;
            }
        }

        emit AddCurrencyToCustomer(bankId, customerGeneralAddress, customerConvertAddress, currencyId );
    }

    function removeCurrencyFromCustomer( uint256 bankId, address customerConvertAddress, uint256 currencyId ) public override onlyParticipatingBank(bankId) {

        address customerGeneralAddress = getCustomerGeneralAddress(customerConvertAddress);

        require( isWhitelisted( customerGeneralAddress ), "This address is not whitelisted");
        require( isValidCurrency(currencyId), "Currency provided is not valid" );
        _supportedCurrencies[ bankId ][ customerConvertAddress ].remove( currencyId );
        
        // Check if caller is a preferredIssuer for this currency 
        if( getCustomerPreferredIssuerForCurrency(customerConvertAddress, currencyId )  == bankId ){
            
            uint256[] memory supportedIssuers = getCustomerSupportedIssuer( customerConvertAddress );
            
            for(uint256 i = 0; i < supportedIssuers.length; i++ ){
                
                //If there is another randomic Issuer that supports this currency, set this one as preferredIssuer for that currency
                if(isCustomerSupportedCurrency( supportedIssuers[i], customerConvertAddress, currencyId )) {
                    _preferredIssuerForCurrency[ customerConvertAddress ][ currencyId ] = supportedIssuers[i];
                    break;
                    //if currency is not supported from any other banks, set zero as value for preferredIssuer
                } else {
                    _preferredIssuerForCurrency[ customerConvertAddress ][ currencyId ] = 0;
                }
            }
        }

        //If the currency removed is the general preferredCurrency verify if there is another Issuer that supports this currency
        // If YES -> general preferredCurrency remains the same
        // If NO -> general PreferredCurrency will be replaced with a randomic currency supported from a supported Issuer
        if( getCustomerPreferredCurrency(customerConvertAddress) == currencyId){
            uint256[] memory supportedIssuers = getCustomerSupportedIssuer( customerConvertAddress );
            bool currencySupported;
            for(uint256 i = 0; i < supportedIssuers.length; i++ ){
                
                if(isCustomerSupportedCurrency( supportedIssuers[i], customerConvertAddress, currencyId )) {
                    currencySupported = true;
                    break;
                } 
            }
            if(!currencySupported && EnumerableSet.length(_supportedCurrencies[ bankId ][ customerConvertAddress ]) != 0 ){
                uint256[] memory supportedCurrencies = getSupportedCurrencies( supportedIssuers[0], customerConvertAddress );
                _customer[ customerConvertAddress ]._preferredCurrency = supportedCurrencies[0];
            }
        }
        
        //If customer does not support on its convertAddress any other currencies remove this bank from the supported Issuers
        if( _supportedCurrencies[ bankId ][ customerConvertAddress ].length() == 0){
            _customer[customerConvertAddress]._supportedIssuers.remove(bankId);
            _customerConvertFromGeneralAndBankId[customerGeneralAddress][bankId].remove(customerConvertAddress);
            
            //If customer does not support any other issuer, its convert address will be disabled and preferred Issuer and Currency will be set as zero (default value)
            if ( EnumerableSet.length(_customer[customerConvertAddress]._supportedIssuers) == 0 ){
                
                _preferredIssuerForCurrency[ customerConvertAddress ][ currencyId ] = 0;
                _customer[ customerConvertAddress ]._preferredCurrency = 0;
                _isCustomerConvertAddress[customerConvertAddress] = false;
            }
        }
        
        emit RemoveCurrencyFromCustomer(bankId, customerGeneralAddress, customerConvertAddress, currencyId );
    } 

    function addCustomerSupportedIssuer( uint256 bankId ) public override onlyConvertAddress {
        
        require ( isValidBank(bankId), "This is not a valid bank ID" );
        address customerGeneralAddress = getCustomerGeneralAddress(msg.sender);
        uint256[] memory supportedCurrencies = getSupportedCurrencies( bankId, msg.sender );

        require ( supportedCurrencies.length > 0, "You don't support this Issuer" );
        require( !_customer[msg.sender]._supportedIssuers.contains( bankId ), "You already support this issuer" );

        
        _supportedIssuerToConvert[bankId].add( msg.sender );
        _customerConvertFromGeneralAndBankId[customerGeneralAddress][bankId].add(msg.sender);

        _customer[msg.sender]._supportedIssuers.add(bankId);    

        emit AddCustomerSupportedIssuer( bankId, msg.sender, customerGeneralAddress);   
    }

     function removeCustomerSupportedIssuer( uint256 bankId ) public override onlyConvertAddress {
        
        require ( isValidBank(bankId), "This is not a valid bank ID" );
        require( _customer[msg.sender]._supportedIssuers.contains( bankId ), "You don't support this issuer" );
        
        address customerGeneralAddress = getCustomerGeneralAddress(msg.sender);
        uint256[] memory supportedCurrencies = getSupportedCurrencies(bankId, msg.sender); 
        _customer[msg.sender]._supportedIssuers.remove(bankId);
        uint256[] memory supportedIssuers = getCustomerSupportedIssuer( msg.sender );  
        
        //Remove the currencies that this customer support for this bankId 
        for( uint256 i = 0; i < supportedCurrencies.length; i++ ){ 
            _supportedCurrencies[ bankId ][ msg.sender ].remove( supportedCurrencies[i] ); 
            bool isSupported = false;
            
            if( supportedIssuers.length > 0 ){
                //Check if the general preferredCurrency is one of the currencies supported by this Issuer
                if(getCustomerPreferredCurrency(msg.sender) == supportedCurrencies[i]) { 

                    for( uint256 j = 0; j < supportedIssuers.length; j++ ){ 
                        if (isCustomerSupportedCurrency( supportedIssuers[j], msg.sender, getCustomerPreferredCurrency(msg.sender)) ) { 
                            isSupported = true;
                        } 
                    }
                    
                    //If no other bank support the removed currency that the issuer removed was supporting, set a new general preferred currency randomly
                    if( !isSupported ) { 
                        uint256[] memory otherSupportedCurrencies = getSupportedCurrencies(supportedIssuers[0], msg.sender);
                        _customer[ msg.sender ]._preferredCurrency = otherSupportedCurrencies[0]; 
                    }
                }

                //If the removed issuer was set as preferred issuer for currency, a new one will be set or the relationship will be removed
                if( isCustomerPreferredIssuerForCurrency( msg.sender, supportedCurrencies[i], bankId) ){ 
                    _preferredIssuerForCurrency[ msg.sender ][ supportedCurrencies[i] ] = 0; 
                    if( supportedIssuers.length > 1 ) { 
                        for( uint256 j = 0; j < supportedIssuers.length; j++ ){ 
                            if(isCustomerSupportedCurrency( supportedIssuers[j], msg.sender, supportedCurrencies[i] ) ) {  
                                _preferredIssuerForCurrency[ msg.sender ][ supportedCurrencies[i] ] = supportedIssuers[j];
                            }
                        }
                    }
                }
        } else {
            //If there are no longer issuers for the customer, set the preferredIssuerForCurrency and the preferredCurrency to default
            _preferredIssuerForCurrency[ msg.sender ][ supportedCurrencies[i] ] = 0;
            _customer[msg.sender]._preferredCurrency = 0;
            }
        }

        _supportedIssuerToConvert[bankId].remove( msg.sender );
        _customerConvertFromGeneralAndBankId[customerGeneralAddress][bankId].remove( msg.sender );

        //If there are no longer issuers for the customer, the convert address is disabled
        if( getCustomerSupportedIssuer(msg.sender).length == 0 ){
            _customerConvertFromGeneralAndBankId[customerGeneralAddress][bankId].remove( msg.sender );
            _isCustomerConvertAddress[ msg.sender ] = false;
        }

        emit RemoveCustomerSupportedIssuer( bankId, msg.sender, customerGeneralAddress);
    }

    function setNewGeneralAddress( address customerGeneralAddress ) public override onlyConvertAddress {

        require( isWhitelisted( customerGeneralAddress ), "The new General Address must be withelisted" );
        address oldGeneralAddress = getCustomerGeneralAddress( msg.sender );
        uint256[] memory bankIds = getBankThatWhitelistedCustomer( oldGeneralAddress );

        for( uint256 i = 0; i < bankIds.length; i++ ){
            if( isBankCustomerWhitelisted( customerGeneralAddress, bankIds[i] ) ) {
                
                _customerConvertFromGeneralAndBankId[ oldGeneralAddress ][ bankIds[ i ] ].remove(msg.sender);
                _customerConvertFromGeneralAndBankId[ customerGeneralAddress ][ bankIds[ i ] ].add(msg.sender);
                _customer[msg.sender]._customerGeneralAddress = customerGeneralAddress;

                emit SetNewGeneralAddress( bankIds[i], msg.sender, customerGeneralAddress, oldGeneralAddress );
            }
        }
    }

    function setCustomerPreferredCurrency( uint256 currencyId ) public override onlyConvertAddress {
        require( isValidCurrency( currencyId ), "Currency provided is not valid" );
        uint256[] memory supportedIssuers = getCustomerSupportedIssuer( msg.sender );

        for( uint256 i = 0; i < supportedIssuers.length; i++){
            if(isCustomerSupportedCurrency( supportedIssuers[i], msg.sender, currencyId )){
                _customer[ msg.sender ]._preferredCurrency = currencyId;
                return;
            }
        }

        revert ("You cannot set this currency as preferred if you don't support it");
    } 

    function setCustomerPreferredIssuerForCurrency( uint256 currencyId, uint256 bankId ) public override onlyConvertAddress {
        require( isValidCurrency( currencyId ), "Currency provided is not valid" );
        require( isCustomerSupportedIssuer( msg.sender, bankId ) && isCustomerSupportedCurrency( bankId, msg.sender, currencyId), "You are not a customer or you do not support this currency for this bank" );
        _preferredIssuerForCurrency[ msg.sender ][ currencyId ] = bankId;
    } 

    function disableConvertAddress() public override onlyConvertAddress(){
        _isCustomerConvertAddress[msg.sender] = false;
    }

    function enableConvertAddress(address customerConvertAddress) public override {
        require( isWhitelisted( msg.sender ) && getCustomerGeneralAddress(customerConvertAddress) == msg.sender, "You are not whitelisted or provided convert address is not linked to your address");
        _isCustomerConvertAddress[customerConvertAddress] = true;
    }
    
    function freezeTokenId( uint256 tokenId) public override onlyOwner {
        require( tokenId >= 1000, "Provided tokenId is not a Bank Token" );
        require( isValidToken( tokenId ), "This is not a valid tokenId" );
        _frozenToken[tokenId] = true;
        
        emit FreezeTokenId( tokenId );
    }

    function unfreezeTokenId( uint256 tokenId) public override onlyOwner {
        require( tokenId >= 1000, "Provided tokenId is not a Bank Token" );
        require( isValidToken( tokenId ), "This is not a valid tokenId" );
        _frozenToken[tokenId] = false;
        
        emit UnfreezeTokenId(tokenId);
    }

    function isWhitelisted( address customerGeneralAddress ) public view override returns (bool){
        return _customerToBankThatWhitelistedHim[customerGeneralAddress].length() > 0;
    }

    function isBankCustomerWhitelisted( address customerGeneralAddress, uint256 bankId ) public view override returns ( bool ) {
        return _customerToBankThatWhitelistedHim[customerGeneralAddress].contains(bankId);
    }

    function isBlacklisted( uint256 bankId, address customerGeneralAddress ) public view override returns (bool){
        return _bankToBlacklistedCustomer[bankId].contains(customerGeneralAddress);
    }

    function isCustomerGeneralAddress( address customerGeneralAddress ) public view override returns ( bool ){
        return _isCustomerGeneralAddress[customerGeneralAddress];
    }

    function isCustomerConvertAddress(address customerAddress) public view override returns (bool) {
        return _isCustomerConvertAddress[customerAddress];
    }

    function isValidCurrency(uint256 currencyId) public view override returns (bool) {
        return currencies.contains(currencyId);
    }

    function isValidToken( uint256 tokenId ) public view override returns (bool) {
        return _validTokenIds.contains(tokenId);
    }

    function isFrozenToken(uint256 tokenId) public view override returns (bool){
        require ( isValidToken(tokenId), "Token provided is not valid" );
        return _frozenToken[tokenId];
    }

    function isParticipatingBank( address bankAddress ) public view override returns (bool){
        return participatingBanks.contains(bankAddress);
    }

    function isValidBank( uint256 bankId ) public view override returns ( bool ){
        return _bank[bankId]._bankId != 0;
    }

    function isCustomerSupportedIssuer( address customerConvertaddress, uint256 bankId ) public view override returns ( bool ){
        return _customer[customerConvertaddress]._supportedIssuers.contains( bankId );
    }

    function isCustomerSupportedCurrency( uint256 bankId, address customerConvertAddress, uint256 currencyId ) public view override returns ( bool ){
        return _supportedCurrencies[ bankId ][ customerConvertAddress ].contains( currencyId );
    }

    function isCustomerPreferredIssuerForCurrency( address customerConvertAddress, uint256 currencyId, uint256 bankId ) public view  returns( bool ) {
        return _preferredIssuerForCurrency[ customerConvertAddress ][ currencyId ] == bankId;
    }

    function getCurrentBankId() public view override returns (uint256){
        return bank_Id;
    }

    function getIssuingAddress(uint256 bankId) public view override returns (address){
        return _bank[bankId]._issuingAddress;
    }

    function getMintAddress(uint256 bankId) public view override returns (address){
        return _bank[bankId]._mintAddress;
    }

    function getRedemptionAddress(uint256 bankId) public view override returns (address){
        return _bank[bankId]._redemptionAddress;
    }

    function getGeneralAddress(uint256 bankId) public view override returns (address){
        return _bank[bankId]._generalAddress;
    }

    function getBankName(uint256 bankId) public view override returns (string memory){
        return _bank[bankId]._name;
    }

    function getCurrencies() public view override returns (uint[] memory) {
        uint256[] memory result = new uint256[](currencies.length());
        for (uint i = 0; i < currencies.length(); i++) {
            result[i] = currencies.at(i);
        }
        return result;
    }

    function getParticipatingBanks() public view override returns(Bank[] memory){

        uint256 currentId = getCurrentBankId();
        uint256 totalBankParticipating = ( currentId / 1000) - 1;
        Bank[] memory _totalParticipatingBanks = new Bank[](totalBankParticipating);
        for (uint i = 1; i <= totalBankParticipating; i++) {
            uint256 x = 1000*i;
            _totalParticipatingBanks[i-1] = _bank[x];
        }
        return _totalParticipatingBanks;
    }

    function getParticipatingBank(uint256 bankId) public view override returns(Bank memory){
        return _bank[bankId];
    }

    function getCustomerGeneralAddress( address customerConvertAddress ) public view override returns (address){
        return _customer[customerConvertAddress]._customerGeneralAddress;
    }

    function getBankThatWhitelistedCustomer(address customerGeneralAddress) public view override returns (uint256[] memory) {

        uint256 length = EnumerableSet.length(_customerToBankThatWhitelistedHim[customerGeneralAddress]);
        uint256[] memory banks = new uint[](length);

        for (uint256 i = 0; i < length; i++) {
            banks[i] = _customerToBankThatWhitelistedHim[customerGeneralAddress].at(i);
        }

        return banks;
    }

    function getBankCustomers(uint256 bankId) internal view returns (address[] memory) {
        
        uint256 length = EnumerableSet.length(_bankToWhitelistedCustomer[bankId]);
        address[] memory customers = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            customers[i] = _bankToWhitelistedCustomer[bankId].at(i);
        }

        return customers;
    }

    function getConvertSupportedIssuer(uint256 bankId) internal view returns (address[] memory) {
        
        uint256 length = EnumerableSet.length(_supportedIssuerToConvert[bankId]);
        address[] memory convertAddresses = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            convertAddresses[i] = _supportedIssuerToConvert[bankId].at(i);
        }

        return convertAddresses;
    }

    function getCustomerSupportedIssuer( address customerConverAddress ) public view override returns ( uint256[] memory ) {
        
        uint256 length = EnumerableSet.length(_customer[ customerConverAddress ]._supportedIssuers);
        uint256[] memory issuerArray = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            issuerArray[i] = _customer[ customerConverAddress ]._supportedIssuers.at(i);
        }

        return issuerArray; 
    }

    function getCustomerConvertAddressFromGeneralAndBankId( address customerGeneralAddress, uint256 bankId ) public view override returns (address[] memory) {
        
        uint256 length = EnumerableSet.length( _customerConvertFromGeneralAndBankId[customerGeneralAddress][ bankId ] );
        address[] memory convertArray = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            convertArray[i] = _customerConvertFromGeneralAndBankId[customerGeneralAddress][ bankId ].at(i);
        }
        return convertArray;
    }

    function getSupportedCurrencies( uint256 bankId, address customerConvertAddress) public view returns (uint256[] memory) {
        
        uint256 length = EnumerableSet.length(_supportedCurrencies[bankId][customerConvertAddress]);
        uint256[] memory result = new uint256[](length );

        for (uint256 i = 0; i < result.length ; i++) {
            result[i] = _supportedCurrencies[bankId][customerConvertAddress].at(i);
        }

        return result;
    }

    function getCustomerPreferredIssuerForCurrency( address customerConvertAddress, uint256 currencyId ) public view override returns( uint256 ) {
        return _preferredIssuerForCurrency[ customerConvertAddress ][ currencyId ];
    }

    function getCustomerPreferredCurrency( address customerConvertAddress ) public view override returns (uint256){
        return _customer[customerConvertAddress]._preferredCurrency;
    }

    // CHG005  
    function getBankidCurrencyFromTokenID( uint256 tokenId ) public pure returns (uint256, uint256){
        uint256 bankId = tokenId/BANK_ID_ADDER;
        bankId = bankId * BANK_ID_ADDER;
        uint256 currency = tokenId - (bankId);
        
        return (bankId, currency);
    }
    
    function deconstruct() public onlyOwner{
    /* we shouldn't call this anyway */
        //selfdestruct(payable(owner()));
    }
    
    function _authorizeUpgrade(address newImplementation) override internal onlyOwner {
    /* only the owner can upgrade; maybe we want later to rotate credentials, so we should
     * enable transferring ownership I guess
     */
    }
}