// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface IEscrowCBMT {
    
    /** 
    * @dev Enum to track the escrow contract ID status 
    */  
    enum EscrowContractStatus {OPEN, ACCEPTED, REJECTED, PROPOSED_BY_PRODUCER, DEPOSITED, COMPLETED, EXTENSION_REQUESTED, REFUNDED}

    /** 
    * @dev Emitted when Payer set conditions 
    */  
    event SetEscrowConditions(address from, address producerConvertAddress, address arbiter, uint256 timelock, uint256 fundDepositDeadline, uint256 amount, uint256 currencyId, uint256 indexed escrowContractId);

    /** 
    * @dev Emitted when Producer set conditions 
    */ 
    event SetProducerEscrowConditions(address from, address payerGeneralAddress, address producerConvertAddress, address arbiter, uint256 timelock, uint256 fundDepositDeadline, uint256 amount, uint256 currencyId, uint256 indexed escrowContractId);
    
     /** 
    * @dev Emitted when Producer accept conditions 
    */  
    event AcceptEscrowContractConditions(address from, uint256 escrowContractId);

     /** 
    * @dev Emitted when Producer reject conditions  
    */  
    event RejectEscrowContractConditions(address from, uint256 escrowContractId);

     /** 
    * @dev Emitted when Payer reject conditions set by Producer 
    */  
    event RejectEscrowContractConditionsByPayer(address from, uint256 escrowContractId);
     
    /** 
    * @dev Emitted when Payer deposit funds
    */  
    event EscrowContractDeposit(address from, address to, address receiver, uint256 escrowContractId, uint256 tokenId, uint256 amount);

    /** 
    * @dev Emitted when Arbiter approve release funds 
    */ 
    event ApproveReleaseFunds(address from, address to, uint256 escrowContractId, uint256 tokenId, uint256 amountReleased);
    
    /** 
    * @dev Emitted when Payer request refund if deadline (lockedTimestamp) expired 
    */ 
    event RequestRefund(address from, uint256 escrowContractId, uint256 tokenId, uint256 amountRefunded);

    /** 
    * @dev Emitted when TSP refund Payer
    */ 
    event RefundPayer(address from, address to, uint256 escrowContractId, uint256 tokenId, uint256 amountToRefund);

    /** 
    * @dev Emitted when Payer/Producer want to extend lockedTimestamp
    */ 
    event OpenEscrowContractDispute(address from, uint256 escrowContractId, uint256 newProposedTimelock);

    /** 
    * @dev Emitted when Arbiter approve the request to extend lockedTimestamp
    */ 
    event LockedTimestampExtended(address from, uint256 escrowContractId, bool approve);

     /** 
    * @dev Emitted when Arbiter does not approve the request to extend lockedTimestamp
    */ 
    event LockedTimestampNotExtended(address from, uint256 escrowContractId, bool approve);

    /** 
    * @dev Struct indicating all info related to an escrow contract ID
    */    
    struct EscrowContract {
        address _payer;
        address _producer;
        address _arbiter;
        uint256 _tokenId;
        uint256 _currencyId;
        uint256 _amount;
        uint256 _lockedTimestamp;
        uint256 _fundDepositDeadline;
        EscrowContractStatus _status;
    }

    /** 
    * @dev Function called by the payer to set the escrow contract conditions
    */    
    function setEscrowContractConditions(address producerConvertAddress, address arbiter, uint256 lockedTimestamp, uint256 fundDepositDeadline, uint256 amount, uint256 currencyId) external;

    /** 
    * @dev Function called by the producer to set the escrow contract conditions
    */  
    function setEscrowContractConditionsByProducer( address payerGeneralAddress, address producerConvertAddress, address arbiter, uint256 lockedTimestamp, uint256 fundDepositDeadline, uint256 amount, uint256 currencyId ) external;

    /** 
    * @dev Function called by the producer to accept the conditions of an escrow contract
    */    
    function acceptEscrowContractConditions(uint256 escrowContractId) external;

    /** 
    * @dev Function called by the producer to reject the conditions of an escrow contract
    */    
    function rejectEscrowContractConditions(uint256 escrowContractId) external;

    /** 
    * @dev Function called by the payer to reject the conditions of an escrow contract set by producer
    */ 
    function rejectEscrowContractConditionsByPayer(uint256 escrowContractId) external;

    /** 
    * @dev Function called by the payer to deposit funds
    */    
    function escrowContractDeposit(uint256 escrowContractId, uint256 tokenId) external;

    /** 
    * @dev Function called by the payer to request for a refund
    */    
    function requestRefund(uint256 escrowContractId) external;

    /** 
    * @dev Function called by the owner to refund the payer in special cases
    */    
    function refundPayer(uint256 escrowContractId) external;

    /** 
    * @dev Function called by the external arbiter to release funds to the producer
    */    
    function approveReleaseFunds(uint256 escrowContractId) external;

    /** 
    * @dev Function called by payer or producer to open a dispute in the case something went wrong with an escrow contract ID
    */    
    function openEscrowContractDispute(uint256 escrowContractId, uint256 newTimeLock) external;

    /** 
    * @dev Function called by the external arbiter to extend timelock to manage a dispute of a specific escrow contract ID  
    */    
    function manageEscrowContractDispute(uint256 escrowContractId, bool approve) external;

    /** 
    * @dev Function called to check if an escrow contract is correctly made
    */      
    function checkEscrowContractConditions(uint256 escrowContractId) external view returns(EscrowContract memory);
    
    /** 
    * @dev Function called to check the status of an EscrowContractStatus
    */      
    function checkEscrowContractStatus(uint256 escrowContractId) external view returns(EscrowContractStatus);

    /** 
    * @dev Function called by Payer to get list of all the contract IDs
    */      
    function getEscrowContractIDs() external view returns(uint256[] memory);
   
    /** 
    * @dev Function called to check if the timelock of an escrow contract is expired
    */    
    function isLockedTimestampExpired(uint256 escrowContractId) external view returns(bool);


    function getEscrowContractDepositDeadline(uint256 escrowContractId) external view returns(uint256);

    /** 
    * @dev Function called to check if the timelock of an escrow contract is expired
    */   
    function getEscrowContractExpiration(uint256 escrowContractId) external view returns(uint256);

    /** 
    * @dev Function called to check if the escrow contract status is OPEN
    */  
    function isEscrowContractOpen(uint256 contractId) external view returns(bool);

    /** 
    * @dev Function called from the arbiter to check the new proposed timelock from the dispute
    */ 
    function getProposedNewTimelock(uint256 escrowContractId) external view returns(uint256);
}