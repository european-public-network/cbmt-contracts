// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GeneralCBMT.sol";
import "./interfaces/ICBMT.sol";

contract CBMT is ICBMT, ERC1155, Ownable(msg.sender) {

    string public _name;
    string public _symbol;
    
    uint256 public constant BLANK_TOKEN_ID = 0;
    // CHG001
    // uint256 public constant EXCHANGE_RATE_BASE = 1000000;
    uint256 public constant EXCHANGE_RATE_BASE = 100000000;
    
    mapping(uint256 => mapping(uint256 => bool)) _netSettlementAvailable;
    mapping(uint256 => mapping(uint256 => uint256 )) _netBankToBankSettlement;
    mapping(uint256 => mapping(uint256 => uint256)) _netAmountToSettle;

    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) internal _bankPairExchangeRate;

    GeneralCBMT public _GeneralCBMT;

    constructor( string memory name_, string memory symbol_, GeneralCBMT __GeneralCBMT, string memory uri_  ) ERC1155(uri_) {
        _name = name_;
        _symbol = symbol_;
        _GeneralCBMT = __GeneralCBMT;
    }

    modifier onlyIssuingAddress(uint256 bankId) {
        require(isIssuingAddress(bankId, msg.sender), "Not issuingAddress");
        _;
    }

    modifier onlyMintAddress(uint256 bankId) {
        require(isMintAddress(bankId, msg.sender), "Not mintAddress");
        _;
    }

    modifier onlyRedemptionAddress(uint256 bankId) {
        require(isRedemptionAddress(bankId, msg.sender), "Not redemptionAddress");
        _;
    }

    modifier onlyGeneralAddress(uint256 bankId) {
        require(isGeneralAddress(bankId, msg.sender), "Not generalAddress");
        _;
    }

    modifier onlyParticipatingBank(uint256 bankId) {
        require( _GeneralCBMT.getIssuingAddress(bankId) == msg.sender || _GeneralCBMT.getMintAddress(bankId) == msg.sender 
            || _GeneralCBMT.getRedemptionAddress(bankId) == msg.sender || _GeneralCBMT.getGeneralAddress(bankId) == msg.sender,
            "Not Participating Bank");       
        _;
    }

    function uri(uint256 tokenId) public view virtual override( ERC1155 ) returns (string memory) {
        return string(abi.encodePacked("https://cbmt.world/schema/", Strings.toHexString(tokenId), "/info.json"));
    }

    function getName( ) public view override returns (string memory) {
        return _name;
    }

    function getSymbol( ) public view override returns (string memory) {
        return _symbol;
    }

    function requestBlankToken( uint256 bankId, uint256 currencyId, uint256 amount ) public override onlyIssuingAddress(bankId) {

        require( _GeneralCBMT.isValidCurrency(currencyId), "Invalid currency");
        require( amount > 0, "Invalid amount" );

        _mint( msg.sender, currencyId, amount, new bytes(0) );

        emit RequestBlankToken( msg.sender, currencyId, amount );
    }

    function stampToken( uint256 bankId, uint256 currencyId, uint256 amount, bytes memory label ) public override onlyMintAddress(bankId) {

        require( _GeneralCBMT.isValidCurrency(currencyId) , "Invalid currency" );
        address issuingAddress = _GeneralCBMT.getIssuingAddress( bankId );

        uint256 tokenId = getTokenIdFromBankId(bankId, currencyId);
        require ( !_GeneralCBMT.isFrozenToken(tokenId), "Token frozen");

        _burn( issuingAddress, currencyId, amount );
        _mint( msg.sender, tokenId, amount, label );
                
        emit StampToken( msg.sender, tokenId,  amount, label );
    }

    function demintToken( uint256 bankId, uint256 currencyId, uint256 amount ) public override onlyIssuingAddress(bankId) {
       
        require( _GeneralCBMT.isValidCurrency(currencyId) , "Invalid currency" );
        address mintAddress = _GeneralCBMT.getMintAddress( bankId );
        
        uint256 tokenId = getTokenIdFromBankId(bankId, currencyId);
        require ( !_GeneralCBMT.isFrozenToken(tokenId), "Token frozen");

        _burn( mintAddress, tokenId, amount);
        _mint( msg.sender, currencyId, amount, new bytes(0));

        emit DemintToken( msg.sender, tokenId, amount );
    }

    function burnBlankToken( uint256 bankId, uint256 currencyId, uint256 amount ) public override onlyIssuingAddress(bankId) {

        require( _GeneralCBMT.isValidCurrency(currencyId) , "Invalid currency" );
        
        _burn( msg.sender, currencyId, amount);

        emit BurnBlankToken( msg.sender, currencyId, amount );
    }

    function requestTokenFromCustomer( uint256 bankId, address customerGeneralAddress, uint256 currencyId, uint256 amountToTransfer ) public override onlyMintAddress(bankId) {

        require( _GeneralCBMT.isValidCurrency(currencyId) , "Invalid currency" );
        if(!_customerCheck( bankId, customerGeneralAddress ) ) revert ("Customer check not passed");
        require( amountToTransfer > 0, "Invalid amount" );
        uint256 tokenId = getTokenIdFromBankId( bankId, currencyId );
        require ( !_GeneralCBMT.isFrozenToken(tokenId), "Token frozen");
        uint256 mintBalance = balanceOf( msg.sender, tokenId );

        if( mintBalance >= amountToTransfer ){
                
            transfer( bankId, customerGeneralAddress, tokenId, amountToTransfer );
            emit TransferTokenToCustomer( msg.sender, customerGeneralAddress, bankId, tokenId, amountToTransfer );
        } else {
            revert("Bank insufficient balance");
        }
    }

    function transfer( uint256 bankId, address to, uint256 tokenId, uint256 amountToTransfer ) public override onlyParticipatingBank( bankId ){
        require ( !_GeneralCBMT.isFrozenToken( tokenId ), "Token frozen");
        require ( !_GeneralCBMT.isCustomerConvertAddress( to ), "Receiver cannot be a Convert Address" );
        
        super.safeTransferFrom( msg.sender, to, tokenId, amountToTransfer, new bytes(0) );
        emit TransferTokenFromBank( msg.sender, to, bankId ,tokenId, amountToTransfer );
    }

    function safeBatchTransferFrom (address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public pure override (ERC1155, IERC1155) {
        revert ( "Disabled" );
    }

    function safeTransferFrom( address from, address to, uint256 tokenId, uint256 amountToTransfer, bytes memory data ) public override(ERC1155, IERC1155) {
        // require( from == msg.sender || isApprovedForAll( from, msg.sender ), "");
        // CHG003 So that the address of other smart contracts is not checked here. CBMT should not check other smart contract addresses, as these run on the customer's dlt.
        require( from == msg.sender, "");
        require( _GeneralCBMT.isCustomerGeneralAddress( from ), "Caller isn't General Address" );
        require ( !_GeneralCBMT.isFrozenToken(tokenId), "Token frozen");
        // CHG002
        // uint256 currencyId = tokenId % 100;
        uint256 currencyId = tokenId % 1000;
        uint256 bankId = getBankIdFromTokenId(tokenId, currencyId);

        require( _blacklistCheck(bankId, from), "Customer check not passed" );

        //This is when the receiver address is a General Address and it's whitelisted
        if( _GeneralCBMT.isCustomerGeneralAddress(to) && _GeneralCBMT.isWhitelisted(to) ) {
            
            require( _blacklistCheck(bankId, to), "Receiver blacklisted" );

            super.safeTransferFrom( from, to, tokenId, amountToTransfer, data );
            emit TransferTokenToGeneralAddress( from, to, bankId, tokenId, currencyId, amountToTransfer );
        } 
        //Same issuer and currency (Case: 1) No conversion is needed 
        else if ( _GeneralCBMT.isCustomerConvertAddress(to) && _GeneralCBMT.isCustomerSupportedIssuer( to, bankId ) && _GeneralCBMT.isCustomerSupportedCurrency( bankId, to, currencyId )) { 
            
            address customerGeneralAddress = _GeneralCBMT.getCustomerGeneralAddress(to);
            require( _blacklistCheck(bankId, customerGeneralAddress), "Receiver blacklisted");
            super.safeTransferFrom( from, customerGeneralAddress, tokenId, amountToTransfer, data );
            emit TransferTokenSupportedIssuerAndCurrency( from, customerGeneralAddress, bankId, tokenId, currencyId, amountToTransfer );
        
        // If the receiver address is a convert address there are 3 different possibility
        } else if( _GeneralCBMT.isCustomerConvertAddress(to) ) {

            require( _blacklistCheck(bankId, _GeneralCBMT.getCustomerGeneralAddress(to)), "Receiver blacklisted");

            super.safeTransferFrom( from, to, tokenId, amountToTransfer, data );
            emit TransferTokenToConvertAddress( from, to, bankId, tokenId, currencyId, amountToTransfer );
            uint256 preferredIssuer = _GeneralCBMT.getCustomerPreferredIssuerForCurrency( to, currencyId );

            //No bank supports incoming currency but receiver support the issuer  ( Case 3: Currency conversion) 
            if ( preferredIssuer == 0 && _GeneralCBMT.isCustomerSupportedIssuer( to, bankId )  ) { 

                emit TransferTokenFromSupportedIssuer( from, bankId, to, tokenId, amountToTransfer); 

            //Different issuer and same or different currency (Case: 2/ Case: 4)
            } else {
                
                // if condition states for the case 4
                if( preferredIssuer == 0 ){
                    uint256 preferredCurrency = _GeneralCBMT.getCustomerPreferredCurrency( to );
                    preferredIssuer = _GeneralCBMT.getCustomerPreferredIssuerForCurrency( to, preferredCurrency );
                }
    
                emit TransferTokenFromNotSupportedIssuer( from, preferredIssuer, to, tokenId, amountToTransfer);
            }
        } else revert ("Transaction not executed");
    }

    function convertTokenFromSupportedIssuer( uint256 tokenId, uint256 bankId, uint256 currencyId, uint256 amountToConvert, address customerConvertAddress ) public override onlyMintAddress(bankId) {

        if ( !_GeneralCBMT.isCustomerConvertAddress(customerConvertAddress)) revert ("Customer address provided is not a convert address");
    
        address customerGeneralAddress = _GeneralCBMT.getCustomerGeneralAddress(customerConvertAddress);
        if(!_customerCheck( bankId, customerGeneralAddress ) ) revert ("Customer check not passed");

        require ( !_GeneralCBMT.isFrozenToken(tokenId), "Token frozen");
        
        address bankGeneralAddress = _GeneralCBMT.getGeneralAddress(bankId);

        //Same issuer different currency (Case: 3)
        if ( _GeneralCBMT.isCustomerSupportedIssuer( customerConvertAddress, bankId ) && !_GeneralCBMT.isCustomerSupportedCurrency( bankId, customerConvertAddress, currencyId ) ) { 
    
            require( bankId + currencyId == tokenId, "Caller is not the designated issuer for this conversion");
            uint256 preferredCurrency = _GeneralCBMT.getCustomerPreferredCurrency(customerConvertAddress);

            uint256 amountToExchange = (amountToConvert * (getExchangeRate( bankId, currencyId, preferredCurrency ))) / EXCHANGE_RATE_BASE;
            uint256 newTokenId = getTokenIdFromBankId( bankId, preferredCurrency);

            require ( !_GeneralCBMT.isFrozenToken(newTokenId), "Token frozen");

            if( balanceOf( msg.sender, newTokenId) >= amountToExchange){
                _safeTransferFrom( customerConvertAddress, bankGeneralAddress, tokenId, amountToConvert, new bytes(0) );               
                _safeTransferFrom( msg.sender, customerGeneralAddress, newTokenId, amountToExchange, new bytes(0) );
                emit ConvertFromSupportedIssuerNotCurrency( customerConvertAddress, bankGeneralAddress, customerGeneralAddress, bankId, tokenId, newTokenId, amountToConvert, amountToExchange );
            }
            else {
                revert("Bank insufficient balance");
            }
        } else revert ("No conversion performed");
    }

    function convertTokenFromNotSupportedIssuer( uint256 tokenId, uint256 bankId, uint256 currencyId, uint256 amountToConvert, address customerConvertAddress ) public override onlyMintAddress(bankId) {
        
        if ( !_GeneralCBMT.isCustomerConvertAddress(customerConvertAddress)) revert ("Customer address provided is not a convert address");       
        address customerGeneralAddress = _GeneralCBMT.getCustomerGeneralAddress(customerConvertAddress);
        if(!_customerCheck( bankId, customerGeneralAddress )  ) revert ("Customer check not passed");

        require ( !_GeneralCBMT.isFrozenToken(tokenId), "Token frozen");
        
        address bankGeneralAddress = _GeneralCBMT.getGeneralAddress(bankId);
        uint256 newTokenId = getTokenIdFromBankId( bankId, currencyId);

        //Different issuer and same currency (Case: 2 )
    
        if ( _GeneralCBMT.isCustomerSupportedCurrency( bankId, customerConvertAddress, currencyId ) ) { 
            
            require ( !_GeneralCBMT.isFrozenToken(newTokenId), "Token frozen");
           
            uint256 preferredIssuer = _GeneralCBMT.getCustomerPreferredIssuerForCurrency( customerConvertAddress, currencyId ) ;
            require( bankId == preferredIssuer, "Caller is not the designated issuer for this conversion");

            if( balanceOf( msg.sender, newTokenId) >= amountToConvert){
                _safeTransferFrom( customerConvertAddress, bankGeneralAddress, tokenId, amountToConvert, new bytes(0) );
                _safeTransferFrom( msg.sender, customerGeneralAddress, newTokenId, amountToConvert, new bytes(0) );
                emit ConvertFromNotSupportedIssuer( msg.sender, customerConvertAddress, bankGeneralAddress, customerGeneralAddress, bankId, tokenId, newTokenId, currencyId, amountToConvert );
            } else {
                revert("Bank insufficient balance");
            }

        //Different currency and issuer (Case: 4 )        
        } else if ( !_GeneralCBMT.isCustomerSupportedCurrency( bankId, customerConvertAddress, currencyId ) ) { 
            
            //This function is split in two because solidity only allows a limited amount of variables
            _convertDifferentCurrencyAndIssuer( tokenId, bankId, currencyId, amountToConvert, customerConvertAddress);

        } else {
            revert ("No conversion performed");
        }
    }

    function _convertDifferentCurrencyAndIssuer( uint256 tokenId, uint256 bankId, uint256 currencyId, uint256 amountToConvert, address customerConvertAddress ) internal onlyMintAddress(bankId) {
        
        address customerGeneralAddress = _GeneralCBMT.getCustomerGeneralAddress(customerConvertAddress);
        address bankGeneralAddress = _GeneralCBMT.getGeneralAddress(bankId); 
        uint256 preferredCurrency = _GeneralCBMT.getCustomerPreferredCurrency(customerConvertAddress);

        require( bankId == _GeneralCBMT.getCustomerPreferredIssuerForCurrency( customerConvertAddress, preferredCurrency ), "Caller is not the designated issuer for this conversion");

        uint256 exchangeRate = getExchangeRate( bankId, currencyId, preferredCurrency );
        uint256 amountToExchange = (amountToConvert * exchangeRate) / EXCHANGE_RATE_BASE;
        uint256 newTokenId = getTokenIdFromBankId( bankId, preferredCurrency);
        require ( !_GeneralCBMT.isFrozenToken(newTokenId), "Token frozen");
        
        if( balanceOf( msg.sender, newTokenId) >= amountToConvert){
            _safeTransferFrom( customerConvertAddress, bankGeneralAddress, tokenId, amountToConvert, new bytes(0) );               
            _safeTransferFrom( msg.sender, customerGeneralAddress, newTokenId, amountToExchange, new bytes(0) );
            emit ConvertFromNotSupportedIssuerAndCurrency( bankGeneralAddress, customerConvertAddress, customerGeneralAddress, tokenId, newTokenId, amountToConvert, amountToExchange );
        } else revert ("Bank insufficient balance");
    }

    function returnTokens( uint256 bankId, uint256 currencyId, uint256 amountToReturn ) public override {
        require( _GeneralCBMT.isCustomerGeneralAddress(msg.sender), "Caller isn't General Address" );
        uint256 tokenId = getTokenIdFromBankId(bankId,currencyId);

        require ( !_GeneralCBMT.isFrozenToken(tokenId), "Token frozen");
        require( _GeneralCBMT.isBankCustomerWhitelisted( msg.sender, bankId ), "Not a bank customer" );

        address redemptionAddress = _GeneralCBMT.getRedemptionAddress(bankId);
        super.safeTransferFrom( msg.sender, redemptionAddress, tokenId, amountToReturn, new bytes(0) );
        emit ReturnTokens( msg.sender, redemptionAddress, bankId, tokenId, currencyId, amountToReturn );
    }

    function startNetSettlement(uint256 fromBankId, uint256 toBankId, uint256 currencyId, uint256 amountToSettle) public override onlyGeneralAddress(fromBankId){
        
        address toGeneralAddress = _GeneralCBMT.getGeneralAddress( toBankId ); 

        require( _GeneralCBMT.isValidCurrency( currencyId ),"Invalid currency");
        require( _GeneralCBMT.isParticipatingBank( toGeneralAddress ) ,"Invalid bank");

        uint256 tokenId = getTokenIdFromBankId(toBankId,currencyId );

        require ( !_GeneralCBMT.isFrozenToken(tokenId), "Token frozen");
        require( balanceOf( msg.sender, tokenId ) >= amountToSettle ,"Insufficient balance");

        _netSettlementAvailable[fromBankId][toBankId] = true;
        _netBankToBankSettlement[fromBankId][toBankId] = currencyId;
        _netAmountToSettle[fromBankId][toBankId] = amountToSettle;

        emit StartNetSettlement(fromBankId, toBankId, currencyId, amountToSettle);
    }

    function acceptNetSettlement(uint256 toBankId, uint256 fromBankId ) public override onlyGeneralAddress(toBankId){
        
        if ( getNetSettlementAvailability( fromBankId, toBankId ) ) {
            
            uint256 currencyId = getNetCurrencyToSettle( fromBankId, toBankId );
            uint256 tokenId_1 = fromBankId + currencyId;
            require ( !_GeneralCBMT.isFrozenToken(tokenId_1), "Token frozen");

            uint256 tokenId_2 = toBankId + currencyId; 
            require ( !_GeneralCBMT.isFrozenToken(tokenId_2), "Token frozen");

            address toBankGeneralAddress = msg.sender; 
            address fromBankGeneralAddress = _GeneralCBMT.getGeneralAddress(fromBankId); 
            

            uint256 tokenThatCanBeSettled = balanceOf( toBankGeneralAddress, tokenId_1 );
            uint256 tokenThatWantToBeSettled = getNetAmountToSettle( fromBankId, toBankId );
        
            require( balanceOf( fromBankGeneralAddress, tokenId_2 ) >= tokenThatWantToBeSettled ,"Bank insufficient balance");

            if( tokenThatCanBeSettled >= tokenThatWantToBeSettled ){
                
                _safeTransferFrom( fromBankGeneralAddress , toBankGeneralAddress, tokenId_2, tokenThatWantToBeSettled, new bytes(0) );
        
                _safeTransferFrom( toBankGeneralAddress , fromBankGeneralAddress, tokenId_1, tokenThatWantToBeSettled, new bytes(0) ); 

                emit NetSettlement( fromBankGeneralAddress , toBankGeneralAddress, fromBankId, toBankId, tokenId_1, tokenId_2, currencyId, tokenThatWantToBeSettled );
    
                _netAmountToSettle[fromBankId][toBankId] = 0;
                _netSettlementAvailable[fromBankId][toBankId] = false;
                
            } else {
                    
                _safeTransferFrom( fromBankGeneralAddress , toBankGeneralAddress, tokenId_2, tokenThatCanBeSettled, new bytes(0) );
        
                _safeTransferFrom( toBankGeneralAddress , fromBankGeneralAddress, tokenId_1, tokenThatCanBeSettled, new bytes(0) ); 

                emit NetSettlement( fromBankGeneralAddress , toBankGeneralAddress, fromBankId, toBankId, tokenId_1, tokenId_2, currencyId, tokenThatCanBeSettled );
    
                uint256 tokenToSettle = tokenThatWantToBeSettled - tokenThatCanBeSettled;

                _netAmountToSettle[fromBankId][toBankId] = tokenToSettle;
                _netSettlementAvailable[fromBankId][toBankId] = true;
            }
        } else {
            revert ("Net settlement unavailable");
        }
    }

    function grossSettlement( uint256 fromBankId, uint256 toBankId, uint256 currencyId, uint256 amountToSettle) public override onlyGeneralAddress(fromBankId){

        address toBankRedemptionAddress = _GeneralCBMT.getRedemptionAddress( toBankId ); 
        require( _GeneralCBMT.isValidCurrency( currencyId ),"Invalid currency");
        require( _GeneralCBMT.isParticipatingBank( toBankRedemptionAddress ) ,"Invalid bank");
        uint256 tokenId = getTokenIdFromBankId( toBankId, currencyId );

        //transfer will check if the token is valid and/or frozen
        transfer( fromBankId, toBankRedemptionAddress, tokenId, amountToSettle );

        emit GrossSettlement( msg.sender, toBankRedemptionAddress, fromBankId, toBankId, currencyId, amountToSettle );
    }

    //ExchangeRate needs to be set in base 1.000.000; if you want an exchange rate of 1.2 the exchange rate that need to be set is 1.200.000
    function setExchangeRate( uint256 bankId, uint256 fromCurrencyId_1, uint256 toCurrencyId_2, uint256 exchangeRate ) public override onlyParticipatingBank(bankId) { 
        require( _GeneralCBMT.isValidCurrency( fromCurrencyId_1 ) && _GeneralCBMT.isValidCurrency( toCurrencyId_2 ) , "Both currencies must be valid");
        _bankPairExchangeRate[ bankId ][ fromCurrencyId_1 ][ toCurrencyId_2 ] = exchangeRate;
    }

    function _customerCheck(uint256 bankId, address customerGeneralAddress) internal view returns(bool) {
        if(  _GeneralCBMT.isWhitelisted( customerGeneralAddress ) && !_GeneralCBMT.isBlacklisted( bankId, customerGeneralAddress ) ){
            return true;
        } else return false; 
    }

    function _blacklistCheck(uint256 bankId, address customerGeneralAddress) internal view returns(bool) {
        if(  !_GeneralCBMT.isBlacklisted( bankId, customerGeneralAddress ) ){
            return true;
        } else return false; 
    }

    function isIssuingAddress(uint256 bankId, address issuingAddress) public view override returns (bool){
        return issuingAddress == _GeneralCBMT.getIssuingAddress(bankId);
    }

    function isMintAddress(uint256 bankId, address mintAddress) public view override returns (bool){
        return mintAddress == _GeneralCBMT.getMintAddress(bankId);
    }

    function isRedemptionAddress(uint256 bankId, address redemptionAddress) public view override returns (bool){
        return redemptionAddress == _GeneralCBMT.getRedemptionAddress(bankId);
     }

    function isGeneralAddress(uint256 bankId, address generalAddress) public view override returns (bool){
        return generalAddress == _GeneralCBMT.getGeneralAddress(bankId);
    }

    function getUri(uint256 tokenId) public view override returns (string memory){}

    function getTokenIdFromBankId(uint256 bankId, uint256 currencyId) public pure override returns (uint256){
        return bankId + currencyId;
    }

    function getBankIdFromTokenId(uint256 tokenId, uint256 currencyId) public pure override returns (uint256){
        return tokenId - currencyId;
    }

    function getNetSettlementAvailability(uint256 fromBankId, uint256 toBankId) public view override returns (bool){
        return _netSettlementAvailable[fromBankId][toBankId];
    }

    function getNetCurrencyToSettle(uint256 fromBankId, uint256 toBankId) public view override returns (uint256){
        return _netBankToBankSettlement[fromBankId][toBankId];
    }

    function getNetAmountToSettle(uint256 fromBankId, uint256 toBankId) public view override returns (uint256){
        return _netAmountToSettle[fromBankId][toBankId];
    }

    function getExchangeRate( uint256 bankId, uint256 fromCurrencyId_1, uint256 toCurrencyId_2  ) public view override returns(uint256){
        return _bankPairExchangeRate[ bankId ][ fromCurrencyId_1 ][ toCurrencyId_2 ];
    }

    function deconstruct() public onlyOwner{
        selfdestruct(payable(owner()));
    }
}