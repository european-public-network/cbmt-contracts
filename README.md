# CBMT (Commerical Bank Money Token) Smart Contract

This smart contract, `CBMT`, implements a system for managing Commerical Bank Money Tokens. It leverages the ERC-1155 standard for representing multiple token types and incorporates upgradeability and access control mechanisms. This contract interacts with a `GeneralCBMT` contract for managing core functionalities like bank and currency registration.

---

## Overview

The contracts included are:

* `CBMT.sol`: Defines the main CBMT token with minting and burning functionalities.
* `GeneralCBMT.sol`: Provides general-purpose utilities for managing the token supply.
* `EscrowCBMT.sol`: Implements an escrow system for secure token transfers between parties.

---

## Core Files

### 1. **Escrow Contract Interface - `IEscrowCBMT.sol`**

This file defines the interface for managing **escrow contracts**. Escrow contracts hold funds on behalf of buyers and sellers, ensuring that funds are only released when both parties agree or when certain conditions are met.

**Key Features**:

* **Escrow Management**: Supports the creation, acceptance, rejection, and status updates of escrow contracts.
* **Deposits and Disputes**: Handles deposits of funds, approves releases, and opens disputes for contract issues.
* **Refunds**: Provides functionality for refunding funds if certain conditions are met.

### 2. **General Bank Contract Interface - `IGeneralCBMT.sol`**

This interface manages the relationship between **banks** and **customers** within the ecosystem. It enables managing customers, their supported currencies, their preferences for issuing banks, and whitelisting/blacklisting customers.

**Key Features**:

* **Banks and Customers**: Adds/removes banks, registers customers, and manages customer preferences.
* **Currency Management**: Banks can add/remove currencies from their list, and customers can choose their preferred currencies.
* **Blacklist and Whitelist**: Tracks and manages the status of customers with banks.
* **Token Management**: Allows freezing/unfreezing tokens and managing general address associations.

### 3. **Customer Contract - `ICustomerCBMT.sol`**

This contract provides functions related to customer information and the interaction with banks in the system. Customers can be associated with one or more banks, support different currencies, and change their preferences.

**Key Features**:

* **Customer Registration**: Functions to register new customers and associate them with banks.
* **Currency Support**: Customers can support multiple currencies and prefer certain currencies.
* **Bank Preferences**: Manage which banks can issue or support transactions for the customer.

### 4. **Transaction Management Contract - `ITransactionCBMT.sol`**

This file defines transactions related to currency conversions, transfers, and management of different kinds of financial transactions.

**Key Features**:

* **Transaction Flow**: Manages how funds are moved between banks and customers.
* **Currency Transfers**: Handles the conversion of one currency to another and the transaction fees involved.
* **Fund Confirmation**: Provides functionality for confirming the successful transfer of funds between parties.

### 5. **Bank Token Management Contract - `IBankTokenCBMT.sol`**

This contract deals with managing tokens issued by different banks. Tokens are used for managing digital assets, representing fiat currencies or digital assets in the blockchain.

**Key Features**:

* **Token Issuance and Management**: Allows banks to issue tokens and manage their validity.
* **Token Freeze/Unfreeze**: Banks or authorized parties can freeze/unfreeze tokens as part of managing their assets.
* **Token Transfers**: Manages the transfer of tokens between addresses for the customer-bank relationship.

### 6. **Utility Contract - `IUtilityCBMT.sol`**

This contract provides utility functions that are commonly used across the other contracts, such as verifying addresses, checking token balances, etc.

**Key Features**:

* **Address Validation**: Validates whether an address belongs to a valid customer or bank.
* **Balance Checking**: Allows checking the balance of specific tokens or currencies associated with customers or banks.
* **Event Logging**: Provides utility functions for logging events when certain actions occur, such as a customer’s transaction or when a bank's token state changes.

---

## Contract Interaction Flow

### Step 1: **Creating and Managing Banks**

* Banks are added to the consortium through the `addParticipatingBank` function in the `IGeneralCBMT` contract.
* Each bank is associated with various addresses: issuing, minting, redemption, and a general address.
* Banks can issue tokens and manage token IDs via the `IBankTokenCBMT` contract.

### Step 2: **Customer Registration and Management**

* Customers can be registered with a specific bank using the `registerCustomer` function in the `IGeneralCBMT` contract.
* Customers are added to the whitelist or blacklist by the bank using functions like `addToWhitelist` or `addToBlacklist`.

### Step 3: **Escrow Contract Creation**

* A payer creates an escrow contract, which holds funds until the contract terms are met.
* The contract can be modified or disputed depending on the situation. Disputes or refunds can be managed by the arbiter or other designated parties.

### Step 4: **Currency Management**

* Banks can add or remove currencies that they support. Customers can choose which currencies they want to use, and this is handled by the `IGeneralCBMT` contract.
* Customers can switch their preferred currency and issuer with the `setCustomerPreferredCurrency` and `setCustomerPreferredIssuerForCurrency` functions.

### Step 5: **Token Handling and Freezing**

* Banks can freeze or unfreeze tokens using the `freezeTokenId` and `unfreezeTokenId` functions.
* Tokens are used for managing digital representations of currencies or assets in the ecosystem.

---

## Security Considerations

1. **Access Control**: Critical operations, such as adding banks or freezing tokens, are restricted to authorized parties (banks or trusted third parties).
2. **Event Tracking**: Every action, such as adding a customer to the whitelist or completing a transaction, emits an event, ensuring that all transactions can be traced and verified.
3. **Blacklist and Whitelist**: Customers can be whitelisted or blacklisted based on their behavior, ensuring that only trusted customers can engage with the ecosystem.
4. **Token Freeze**: Banks can freeze or unfreeze tokens, providing additional control over the flow of assets.

---

Based on the content of the three Solidity smart contracts you provided — `CBMT.sol`, `GeneralCBMT.sol`, and `EscrowCBMT.sol` — here is a detailed and professional `README.md` file that explains their purpose and functionality:

---

# CBMT Smart Contract Suite

This repository contains a suite of smart contracts for managing a blockchain-based carbon credit system built around the CBMT (Carbon-Based Monetary Token) concept. It includes token definitions, general-purpose interactions, and an escrow mechanism.

---

## Contracts

### 1. CBMT.sol

**Purpose:**
Implements the CBMT ERC20 token, with support for minting and burning by authorized entities.

**Key Features:**

* Inherits from OpenZeppelin's ERC20 standard.
* Restricted minting and burning via a `generalContract` address.
* Supports `updateGeneralContract` function for admin control.

**Functions:**

* `mint(address to, uint256 amount)`: Mints tokens to a specified address (callable only by the `generalContract`).
* `burn(address from, uint256 amount)`: Burns tokens from a specified address (callable only by the `generalContract`).
* `updateGeneralContract(address _newGeneralContract)`: Admin function to update the general contract.

---

### 2. GeneralCBMT.sol

**Purpose:**
Serves as a management layer for token issuance and destruction, interacting with the CBMT contract.

**Key Features:**

* Allows users to request minting or burning of CBMT tokens.
* Maintains an authorized token address (`CBMT`) for controlled interactions.

**Functions:**

* `mintCBMT(address to, uint256 amount)`: Mints CBMT tokens to a specified address.
* `burnCBMT(address from, uint256 amount)`: Burns CBMT tokens from a specified address.
* `updateCBMTAddress(address _cbmtAddress)`: Updates the token address (admin only).

---

### 3. EscrowCBMT.sol

**Purpose:**
A trustless escrow system that locks CBMT tokens until conditions are met.

**Key Features:**

* Manages escrow-based deposits with time locks.
* Allows either party to withdraw based on agreement or timeout.
* Protects both buyer and seller in a transaction.

**Functions:**

* `deposit(address seller, uint256 amount, uint256 timeLock)`: Buyer deposits tokens into escrow.
* `withdrawBySeller(uint256 escrowId)`: Allows seller to withdraw after timelock.
* `withdrawByBuyer(uint256 escrowId)`: Allows buyer to cancel escrow after timelock.

---

## Installation & Deployment

1. **Install dependencies** (if using Hardhat or Truffle):

   ```bash
   npm install
   ```

2. **Compile contracts:**

   ```bash
   npx hardhat compile
   ```

3. **Deploy to a local or test network using your preferred tool.**

---

## Conclusion

This project creates a comprehensive decentralized financial ecosystem where banks, customers, and various currencies interact. The use of different contracts ensures that the system is modular, with each contract handling specific functions related to customers, banks, tokens, transactions, and escrow. The system is designed for transparency, auditability, and secure transactions.
