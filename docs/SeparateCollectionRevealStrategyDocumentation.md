# SeparateCollectionRevealStrategy Documentation

## Overview
The `SeparateCollectionRevealStrategy` implements the `IRevealStrategy` interface and provides a mechanism to reveal NFTs by transferring them to a separate collection. It uses randomness provided by Chainlink VRF to determine the reveal outcome.

---

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Dependencies](#dependencies)
4. [State Variables](#state-variables)
5. [Core Functionalities](#core-functionalities)
    - [Setting the Reveal Module](#setting-the-reveal-module)
    - [Revealing Tokens](#revealing-tokens)
6. [Modifiers](#modifiers)
7. [Security Considerations](#security-considerations)
8. [Usage Examples](#usage-examples)
9. [Events](#events)

---

## Architecture
The `SeparateCollectionRevealStrategy` is designed to:
- Transfer NFTs to a separate collection upon reveal.
- Use randomness to determine the reveal outcome.
- Ensure only the designated `RevealModule` can trigger the reveal process.

---

## Dependencies
The strategy relies on:
- **IRevealStrategy**: Ensures compatibility with the `RevealModule`.
- **ISPNFT**: Interface for interacting with the NFT contract.
- **MetadataGenerator**: Library for generating metadata.
- **OpenZeppelin Ownable**: Provides access control for the owner.

---

## State Variables
- `spNFT`: Instance of the NFT contract (`ISPNFT`).
- `revealModule`: Address of the `RevealModule` authorized to trigger the reveal process.

---

## Core Functionalities

### Setting the Reveal Module
The `setRevealModule` function allows the owner to set the address of the `RevealModule`.  
- **Requirements**:
  - Can only be called once.
  - The provided address must not be the zero address.

### Revealing Tokens
The `reveal` function implements the `IRevealStrategy` interface.  
- **Process**:
  - Generates metadata using the `MetadataGenerator` library.
  - Transfers the NFT to a separate collection.
  - Emits an event to log the reveal process.

---

## Modifiers
- **onlyRevealModule**: Restricts function calls to the designated `RevealModule`.

---

## Security Considerations
- **Access Control**: Only the `RevealModule` can trigger the reveal process.
- **Randomness Integrity**: Ensures randomness is securely used to generate metadata.
- **Single Use**: The `setRevealModule` function can only be called once to prevent unauthorized changes.

---

## Usage Examples
### Setting the Reveal Module
```solidity
separateCollectionRevealStrategy.setRevealModule(revealModuleAddress);
```

### Revealing a Token
```solidity
bool success = separateCollectionRevealStrategy.reveal(nftContract, tokenId, randomResult);
```

---

## Events
- **RevealModuleSetForStrategy**: Emitted when the `RevealModule` is set.
  - `address indexed revealModule`
- **TokenRevealExecuted**: Emitted when a token is successfully revealed.
  - `uint256 indexed tokenId`
  - `uint256 randomResult`

---
