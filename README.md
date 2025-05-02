# CBMT (Central Bank Money Token) Smart Contract

This smart contract, `CBMT`, implements a system for managing Central Bank Money Tokens. It leverages the ERC-1155 standard for representing multiple token types and incorporates upgradeability and access control mechanisms. This contract interacts with a `GeneralCBMT` contract for managing core functionalities like bank and currency registration.

## Overview

The `CBMT` contract enables participating banks to:

- **Request Blank Tokens:** Obtain fungible tokens representing a specific currency.
- **Stamp Tokens:** Convert blank tokens into unique, bank-issued tokens with associated metadata (label).
- **Demint Tokens:** Convert bank-issued tokens back into blank tokens.
- **Burn Blank Tokens:** Destroy blank tokens.
- **Transfer Tokens:** Send bank-issued tokens to other participating banks or whitelisted customers.
- **Convert Tokens:** Facilitate currency exchange between different bank-issued tokens, interacting with customer convert addresses.
- **Return Tokens:** Allow customers to return tokens to the issuing bank's redemption address.
- **Participate in Net and Gross Settlements:** Settle token balances with other participating banks.
- **Set Exchange Rates:** Define exchange rates between different currencies for conversion purposes.

## Architecture

The contract utilizes the following OpenZeppelin libraries:

- **`ERC1155Upgradeable`:** Provides the base implementation for multi-token management with upgradeability.
- **`EnumerableSet`:** (Although imported, it's not directly used in the current version of the contract.)
- **`Strings`:** Used for converting token IDs to hexadecimal strings for URI construction.
- **`OwnableUpgradeable`:** Implements basic access control, allowing only the owner to perform sensitive operations like upgrades.
- **`UUPSUpgradeable`:** Enables upgradeability of the contract logic.

It also interacts with:

- **`GeneralCBMT`:** An external contract responsible for managing participating banks, currencies, and address roles (issuing, minting, redemption, general), as well as whitelisting and blacklisting.
- **`ICBMT`:** An interface defining the functions of the `CBMT` contract.

## Key Features and Functionality

### Token Management

- **Blank Tokens (ID 0):** Represent base currency units before being issued by a specific bank.
- **Bank-Issued Tokens:** Unique tokens identified by a combination of `bankId` and `currencyId`. The token ID is calculated as `bankId + currencyId`.
- **Token URI:** Metadata for each bank-issued token is dynamically generated based on the token ID, following the format `https://cbmt.world/schema/<hex_token_id>/info.json`.

### Access Control

The contract employs several modifiers to restrict access to specific functions:

- **`onlyIssuingAddress(uint256 bankId)`:** Allows only the designated issuing address for a given `bankId`.
- **`onlyMintAddress(uint256 bankId)`:** Allows only the designated minting address for a given `bankId`.
- **`onlyRedemptionAddress(uint256 bankId)`:** Allows only the designated redemption address for a given `bankId`.
- **`onlyGeneralAddress(uint256 bankId)`:** Allows only the designated general address for a given `bankId`.
- **`onlyParticipatingBank(uint256 bankId)`:** Allows any of the registered addresses (issuing, minting, redemption, general) for a given `bankId`.

### Token Operations

- **`requestBlankToken`:** An issuing bank can request a certain amount of blank tokens for a specific currency.
- **`stampToken`:** A minting bank can convert blank tokens into bank-specific tokens, associating a label (metadata) with them. This burns the blank tokens and mints the corresponding bank-issued tokens.
- **`demintToken`:** An issuing bank can convert bank-specific tokens back into blank tokens. This burns the bank-issued tokens and mints the corresponding amount of blank tokens.
- **`burnBlankToken`:** An issuing bank can destroy blank tokens.
- **`requestTokenFromCustomer`:** A minting bank can transfer its own issued tokens to a customer's general address, provided the customer passes the necessary checks and the bank has sufficient balance.
- **`transfer`:** A participating bank can transfer its issued tokens to other participating banks or whitelisted customer general addresses. Transfers to convert addresses are also allowed.
- **`safeTransferFrom`:** Overrides the ERC-1155 function to implement specific business logic, including checks for frozen tokens, blacklisted recipients, and handling transfers to general and convert addresses.
- **`convertTokenFromSupportedIssuer`:** Allows a minting bank to convert tokens of the same issuing bank but a different currency for a customer with a convert address.
- **`convertTokenFromNotSupportedIssuer`:** Enables a minting bank to convert tokens from a different issuing bank for a customer with a convert address, handling both same and different currency scenarios.
- **`returnTokens`:** Allows a whitelisted customer to return bank-issued tokens to the issuing bank's redemption address.

### Settlement

- **`startNetSettlement`:** A general address of a bank can initiate a net settlement with another participating bank for a specific currency and amount.
- **`acceptNetSettlement`:** The general address of the receiving bank can accept a net settlement request, transferring the agreed-upon amount of tokens.
- **`grossSettlement`:** A general address of a bank can directly transfer tokens to the redemption address of another participating bank for immediate settlement.

### Exchange Rates

- **`setExchangeRate`:** A participating bank can set the exchange rate between two different currencies. The exchange rate is stored with a base of 1,000,000.
- **`getExchangeRate`:** Retrieves the exchange rate between two currencies for a specific bank.

### Utility Functions

- **`getContractVersion`:** Returns the current version of the contract.
- **`uri`:** Returns the URI for a given token ID.
- **`getName`:** Returns the name of the token contract.
- **`getSymbol`:** Returns the symbol of the token contract.
- **`getTokenIdFromBankId`:** Calculates the token ID from a bank ID and currency ID.
- **`getBankIdFromTokenId`:** Extracts the bank ID from a token ID and currency ID.
- **`getNetSettlementAvailability`:** Checks if a net settlement is available between two banks.
- **`getNetCurrencyToSettle`:** Returns the currency ID for a pending net settlement.
- **`getNetAmountToSettle`:** Returns the amount to be settled in a pending net settlement.
- **`isIssuingAddress`, `isMintAddress`, `isRedemptionAddress`, `isGeneralAddress`:** Check if a given address is the designated address for a specific role in a bank.

### Internal Functions

- **`_customerCheck`:** Internal check to verify if a customer general address is whitelisted and not blacklisted by a specific bank.
- **`_blacklistCheck`:** Internal check to verify if a customer general address is not blacklisted by a specific bank.
- **`_convertDifferentCurrencyAndIssuer`:** Internal function to handle token conversion with different currencies and issuers.
- **`_authorizeUpgrade`:** Overrides the UUPSUpgradeable function to define who can authorize contract upgrades (currently only the owner).

## Important Notes

- This contract relies heavily on the `GeneralCBMT` contract for core data and validation. Ensure the `GeneralCBMT` contract is properly deployed and configured.
- The contract implements upgradeability using the UUPS proxy pattern. Deployments should involve a proxy contract pointing to this implementation contract.
- Access control is crucial. Ensure that the correct addresses for issuing, minting, redemption, and general roles are set in the `GeneralCBMT` contract.
- The exchange rates are stored with a base of 1,000,000. Calculations involving exchange rates should account for this.
- The `safeBatchTransferFrom` function is explicitly disabled.

## Deployment

To deploy this contract:

1. Deploy the `GeneralCBMT` contract and configure it with participating banks, currencies, and their respective addresses.
2. Deploy a UUPS proxy contract.
3. Deploy this `CBMT` implementation contract.
4. Initialize the `CBMT` contract through the proxy, providing the contract name, symbol, the address of the deployed `GeneralCBMT` contract, and the base URI for token metadata.
5. Transfer ownership of the proxy contract to the desired administrator.

## Interactions

Interact with the deployed `CBMT` contract using a compatible Ethereum wallet or through smart contract interaction libraries (e.g., Ethers.js, Web3.js). Ensure you have the correct contract address and ABI.