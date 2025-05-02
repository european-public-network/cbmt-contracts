// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./interfaces/IEscrowCBMT.sol";
import "./CBMT.sol";
import "./GeneralCBMT.sol";

contract EscrowCBMT is IEscrowCBMT, Ownable(msg.sender), ERC1155Holder {
    
    using EnumerableSet for EnumerableSet.UintSet;

    CBMT public _CBMT;
    GeneralCBMT public _GeneralCBMT;

    uint256 public nextContractId = 1;

    mapping(uint256 => EscrowContract) public _escrowContracts;
    mapping(address => EnumerableSet.UintSet) internal _payerEscrowContracts;
    mapping(uint256 => uint256) public _newProposedEscrowTimelock;

    modifier onlyProducer(uint256 escrowContractId) {
        address generalProducerAddress = _GeneralCBMT.getCustomerGeneralAddress(_escrowContracts[escrowContractId]._producer);
        require(msg.sender == generalProducerAddress || msg.sender == _escrowContracts[escrowContractId]._producer, "Only producer can call this function");
        _;
    }

    modifier onlyPayer(uint256 escrowContractId) {
        require(msg.sender == _escrowContracts[escrowContractId]._payer, "Only payer can call this function");
        _;
    }

    modifier onlyArbiter(uint256 escrowContractId) {
        require(msg.sender == _escrowContracts[escrowContractId]._arbiter, "Only arbiter can call this function");
        _;
    }

    modifier onlyAuthorized(uint256 escrowContractId) {
        address generalProducerAddress = _GeneralCBMT.getCustomerGeneralAddress(_escrowContracts[escrowContractId]._producer);
        require(msg.sender == generalProducerAddress || msg.sender == _escrowContracts[escrowContractId]._producer|| msg.sender == _escrowContracts[escrowContractId]._payer, "You are not authorized to call this function");
        _;
    }

    constructor(CBMT __CBMT, GeneralCBMT __GeneralCBMT) {
        _CBMT = __CBMT;
        _GeneralCBMT = __GeneralCBMT;
    }

    function setEscrowContractConditions( address producerConvertAddress, address arbiter, uint256 lockedTimestamp, uint256 fundDepositDeadline, uint256 amount, uint256 currencyId ) public override {
        
        require(amount > 0, "Amount must be greater than zero");
        require(_GeneralCBMT.isCustomerConvertAddress(producerConvertAddress), "Producer address must be a convert address!");
        require(arbiter != address(0), "Arbiter address cannot be zero address");
        require(lockedTimestamp > block.timestamp, "Locked timestamp must be in the future");
        require(fundDepositDeadline > block.timestamp && fundDepositDeadline < lockedTimestamp, "Deposit deadline must be in the future and less then locked Timestamp");

        require(_GeneralCBMT.isValidCurrency(currencyId), "Currency Id not valid");

        _escrowContracts[nextContractId] = EscrowContract({
            _payer: msg.sender,
            _producer: producerConvertAddress,
            _arbiter: arbiter,
            _tokenId: 0,
            _currencyId: currencyId,
            _amount: amount,
            _lockedTimestamp: lockedTimestamp,
            _fundDepositDeadline: fundDepositDeadline,
            _status: EscrowContractStatus.OPEN
        });
        _payerEscrowContracts[msg.sender].add(nextContractId);

        emit SetEscrowConditions(msg.sender, producerConvertAddress, arbiter, lockedTimestamp, fundDepositDeadline, amount, currencyId, nextContractId);
        nextContractId++;   
    }

    function setEscrowContractConditionsByProducer( address payerGeneralAddress, address producerConvertAddress, address arbiter, uint256 lockedTimestamp, uint256 fundDepositDeadline, uint256 amount, uint256 currencyId ) public override {
        
        require(amount > 0, "Amount must be greater than zero");
        require(_GeneralCBMT.isCustomerGeneralAddress(payerGeneralAddress), "Payer address must be a general address!");
        require(msg.sender == producerConvertAddress || msg.sender == _GeneralCBMT.getCustomerGeneralAddress(producerConvertAddress), "Caller address must be linked to producer convert address");
        require(_GeneralCBMT.isCustomerConvertAddress(producerConvertAddress), "Producer address must be a convert address!");
        require(arbiter != address(0), "Arbiter address cannot be zero address");
        require(lockedTimestamp > block.timestamp, "Locked timestamp must be in the future");
        require(fundDepositDeadline > block.timestamp && fundDepositDeadline < lockedTimestamp, "Deposit deadline must be in the future and less then locked Timestamp");
        require(_GeneralCBMT.isValidCurrency(currencyId), "Currency Id not valid");

        _escrowContracts[nextContractId] = EscrowContract({
            _payer: payerGeneralAddress,
            _producer: producerConvertAddress,
            _arbiter: arbiter,
            _tokenId: 0,
            _currencyId: currencyId,
            _amount: amount,
            _lockedTimestamp: lockedTimestamp,
            _fundDepositDeadline: fundDepositDeadline,
            _status: EscrowContractStatus.PROPOSED_BY_PRODUCER
        });
        _payerEscrowContracts[payerGeneralAddress].add(nextContractId);

        emit SetProducerEscrowConditions(msg.sender, payerGeneralAddress, producerConvertAddress, arbiter, lockedTimestamp, fundDepositDeadline, amount, currencyId, nextContractId);
        nextContractId++;   
    }

    function acceptEscrowContractConditions(uint256 escrowContractId) public override onlyProducer(escrowContractId) {

        require(isEscrowContractOpen(escrowContractId), "Escrow Contract ID is not OPEN");
        _escrowContracts[escrowContractId]._status = EscrowContractStatus.ACCEPTED;

        emit AcceptEscrowContractConditions(msg.sender, escrowContractId);
    }

    function rejectEscrowContractConditions(uint256 escrowContractId) public override onlyProducer(escrowContractId) {

        require(isEscrowContractOpen(escrowContractId), "Escrow Contract ID is not OPEN");
        _escrowContracts[escrowContractId]._status = EscrowContractStatus.REJECTED;

        emit RejectEscrowContractConditions(msg.sender, escrowContractId);
    }

    function rejectEscrowContractConditionsByPayer(uint256 escrowContractId) public override onlyPayer(escrowContractId) {

        require( checkEscrowContractStatus(escrowContractId) == EscrowContractStatus.PROPOSED_BY_PRODUCER, "Escrow contract status must be PROPOSED_BY_PRODUCER");
        _escrowContracts[escrowContractId]._status = EscrowContractStatus.REJECTED;

        emit RejectEscrowContractConditionsByPayer(msg.sender, escrowContractId);
    }

    function escrowContractDeposit(uint256 escrowContractId, uint256 tokenId) public override onlyPayer(escrowContractId){

        require(_GeneralCBMT.isCustomerConvertAddress(_escrowContracts[escrowContractId]._producer), "Producer address is not a convert address");
        require(!_GeneralCBMT.isFrozenToken(tokenId), "Token is frozen");
        uint256 currencyId = tokenId % 100;
        require( currencyId == _escrowContracts[escrowContractId]._currencyId, "Token ID does not match Currency Id conditions");
        require(block.timestamp <= getEscrowContractDepositDeadline(escrowContractId), "Fund deposited deadline expired");
        require( checkEscrowContractStatus(escrowContractId) == EscrowContractStatus.ACCEPTED || checkEscrowContractStatus(escrowContractId) == EscrowContractStatus.PROPOSED_BY_PRODUCER, "Escrow contract status must be ACCEPTED or PROPOSED_BY_PRODUCER");
        require(_CBMT.balanceOf(msg.sender, tokenId) >= _escrowContracts[escrowContractId]._amount, "You don't have enough balance");
        require(_CBMT.isApprovedForAll(msg.sender, address(this)), "Escrow contract is not approved");
        _CBMT.safeTransferFrom(msg.sender, address(this), tokenId, _escrowContracts[escrowContractId]._amount, new bytes(0));

        _escrowContracts[escrowContractId]._tokenId = tokenId;
        _escrowContracts[escrowContractId]._status = EscrowContractStatus.DEPOSITED;

        emit EscrowContractDeposit(msg.sender, _escrowContracts[escrowContractId]._producer, address(this), escrowContractId, tokenId, _escrowContracts[escrowContractId]._amount);
    }

    function approveReleaseFunds(uint256 escrowContractId) public override onlyArbiter(escrowContractId){
        
        require( checkEscrowContractStatus(escrowContractId) == EscrowContractStatus.DEPOSITED, "Escrow contract status must be Deposited");
        _CBMT.safeTransferFrom( address(this), _escrowContracts[escrowContractId]._producer, _escrowContracts[escrowContractId]._tokenId, _escrowContracts[escrowContractId]._amount, new bytes(0));
        _escrowContracts[escrowContractId]._status = EscrowContractStatus.COMPLETED; 

        emit ApproveReleaseFunds(msg.sender, _escrowContracts[escrowContractId]._producer, escrowContractId, _escrowContracts[escrowContractId]._tokenId, _escrowContracts[escrowContractId]._amount);
    }

    function requestRefund(uint256 escrowContractId) public override onlyPayer(escrowContractId){
        
        require(isLockedTimestampExpired(escrowContractId), "Timelock not expired yet");
        require(checkEscrowContractStatus(escrowContractId) == EscrowContractStatus.DEPOSITED, "Escrow contract status must be Deposited");
        _CBMT.safeTransferFrom( address(this), _escrowContracts[escrowContractId]._payer, _escrowContracts[escrowContractId]._tokenId, _escrowContracts[escrowContractId]._amount, new bytes(0));
        _escrowContracts[escrowContractId]._status = EscrowContractStatus.REFUNDED;

        emit RequestRefund(msg.sender, escrowContractId, _escrowContracts[escrowContractId]._tokenId, _escrowContracts[escrowContractId]._amount);
    }
   
    function refundPayer(uint256 escrowContractId) public override onlyOwner{
        
        require(checkEscrowContractStatus(escrowContractId) == EscrowContractStatus.DEPOSITED || checkEscrowContractStatus(escrowContractId) == EscrowContractStatus.EXTENSION_REQUESTED , "Escrow contract status must be DEPOSTED or EXTENSION_REQUESTED");
        _CBMT.safeTransferFrom( address(this), _escrowContracts[escrowContractId]._payer, _escrowContracts[escrowContractId]._tokenId, _escrowContracts[escrowContractId]._amount, new bytes(0));
        _escrowContracts[escrowContractId]._status = EscrowContractStatus.REFUNDED; 

        emit RefundPayer(msg.sender, _escrowContracts[escrowContractId]._payer, escrowContractId, _escrowContracts[escrowContractId]._tokenId, _escrowContracts[escrowContractId]._amount);
    }

    function openEscrowContractDispute(uint256 escrowContractId, uint256 newProposedLockedTimestamp) public override onlyAuthorized(escrowContractId){
        
        require( block.timestamp < getEscrowContractExpiration(escrowContractId), "Escrow contract is already expired");
        require( newProposedLockedTimestamp > getEscrowContractExpiration(escrowContractId), "Proposed Locked Timestamp must be greater than the previous LockedTimestamp");
        require( checkEscrowContractStatus(escrowContractId) == EscrowContractStatus.DEPOSITED,"Escrow contract status must be Deposited");
        _newProposedEscrowTimelock[escrowContractId] = newProposedLockedTimestamp;
        _escrowContracts[escrowContractId]._status = EscrowContractStatus.EXTENSION_REQUESTED;

        emit OpenEscrowContractDispute(msg.sender, escrowContractId, newProposedLockedTimestamp);
    }

    function manageEscrowContractDispute(uint256 escrowContractId, bool approve) public override onlyArbiter(escrowContractId){
       
        require(checkEscrowContractStatus(escrowContractId) == EscrowContractStatus.EXTENSION_REQUESTED, "Escrow contract status must be EXTENSION_REQUESTED");
        
        if(approve){
            _setNewTimelock(escrowContractId);
            _escrowContracts[escrowContractId]._status = EscrowContractStatus.DEPOSITED;

            emit LockedTimestampExtended(msg.sender, escrowContractId, approve);
        } else {
            _newProposedEscrowTimelock[escrowContractId] = 0; 
            _escrowContracts[escrowContractId]._status = EscrowContractStatus.DEPOSITED;

            emit LockedTimestampNotExtended(msg.sender, escrowContractId, approve);
        }
    }

    function _setNewTimelock(uint256 escrowContractId) internal{

        uint256 newTimelock = getProposedNewTimelock(escrowContractId);
        _escrowContracts[escrowContractId]._lockedTimestamp = newTimelock;
        _newProposedEscrowTimelock[escrowContractId] = 0;
    }

    function getEscrowContractIDs() public view override returns(uint256[] memory){
        uint256 length = EnumerableSet.length(_payerEscrowContracts[msg.sender]);
        uint256[] memory contractsIDs = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            contractsIDs[i] = _payerEscrowContracts[msg.sender].at(i);
        }

        return contractsIDs;
    }

    function isEscrowContractOpen(uint256 contractId) public view override returns (bool) {
    
        require(contractId < nextContractId, "Escrow contract ID does not exist");
        EscrowContractStatus status = _escrowContracts[contractId]._status;
        return (status == EscrowContractStatus.OPEN);
    }

    function checkEscrowContractConditions(uint256 escrowContractId) public view override returns(EscrowContract memory){
        return _escrowContracts[escrowContractId];
    }

    function checkEscrowContractStatus(uint256 escrowContractId) public view override returns(EscrowContractStatus) {
        return _escrowContracts[escrowContractId]._status;
    }

    function getEscrowContractDepositDeadline(uint256 escrowContractId) public view override returns(uint256) {
        return _escrowContracts[escrowContractId]._fundDepositDeadline;
    }

    function getProposedNewTimelock(uint256 escrowContractId) public view override returns(uint256) { 
        return _newProposedEscrowTimelock[escrowContractId];
    }

    function getEscrowContractExpiration(uint256 escrowContractId) public view override returns(uint256){
        return _escrowContracts[escrowContractId]._lockedTimestamp;
    }

    function isLockedTimestampExpired(uint256 escrowContractId) public view override returns(bool){
        
        uint256 expirationTime = getEscrowContractExpiration(escrowContractId);
        return( block.timestamp > expirationTime );
    }

    function deconstruct() public onlyOwner{
        uint256[] memory currencies = _GeneralCBMT.getCurrencies();
        uint256 lastBankID = _GeneralCBMT.getCurrentBankId();

        for(uint256 i = 100; i < lastBankID; i += 100) {
            for( uint256 j; j < currencies.length ; j++ ) {
                
                if(_GeneralCBMT.isValidToken(i + currencies[j])){
                    if( _CBMT.balanceOf(address(this), i + currencies[j] ) > 0) revert ("EscrowCBMT Contract still holds funds");
                }  
            }
        } 
        selfdestruct(payable(owner()));
    }
}