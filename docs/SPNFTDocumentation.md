# SPNFT Documentation

## Overview
The `SPNFT` contract represents the base NFT collection. It provides functionality for minting, transferring, and managing NFTs. Additionally, it integrates with the reveal module to support metadata updates upon token reveal.

---

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Dependencies](#dependencies)
4. [State Variables](#state-variables)
5. [Core Functionalities](#core-functionalities)
    - [Minting Tokens](#minting-tokens)
    - [Updating Metadata](#updating-metadata)
6. [Modifiers](#modifiers)
7. [Security Considerations](#security-considerations)
8. [Usage Examples](#usage-examples)
9. [Events](#events)

---

## Architecture
The `SPNFT` contract is designed to:
- Represent a collection of NFTs.
- Allow authorized modules (e.g., reveal module) to update metadata.
- Provide standard ERC721 functionality.

---

## Dependencies
The contract relies on:
- **ERC721**: Implements the NFT standard.
- **OpenZeppelin Ownable**: Provides access control for the owner.
- **RevealModule**: Integrates with the reveal module for metadata updates.

---

## State Variables
- `baseURI`: The base URI for token metadata.
- `revealedMetadata`: Mapping of token IDs to their revealed metadata.

---

## Core Functionalities

### Minting Tokens
The `mint` function allows the owner to mint new NFTs.  
- **Requirements**:
  - Only the owner can mint tokens.
  - The token ID must not already exist.

### Updating Metadata
The `setTokenRevealed` function allows the reveal module to update the metadata of a token.  
- **Requirements**:
  - Only callable by the reveal module.
  - The token must exist.

---

## Modifiers
- **onlyRevealModule**: Restricts function calls to the designated reveal module.

---

## Security Considerations
- **Access Control**: Only the owner can mint tokens, and only the reveal module can update metadata.
- **Metadata Integrity**: Ensures metadata updates are authorized and valid.

---

## Usage Examples
### Minting a Token
```solidity
spNFT.mint(toAddress, tokenId);
```

### Updating Metadata
```solidity
spNFT.setTokenRevealed(tokenId, newMetadata);
```

---

## Events
- **TokenMinted**: Emitted when a new token is minted.
  - `address indexed to`
  - `uint256 indexed tokenId`
- **TokenMetadataUpdated**: Emitted when a token's metadata is updated.
  - `uint256 indexed tokenId`
  - `string newMetadata`

---
