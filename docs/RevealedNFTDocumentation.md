# RevealedNFT Documentation

## Overview
The `RevealedNFT` contract represents a separate collection of NFTs that have been revealed. It provides functionality for minting revealed tokens and managing their metadata.

---

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Dependencies](#dependencies)
4. [State Variables](#state-variables)
5. [Core Functionalities](#core-functionalities)
    - [Minting Revealed Tokens](#minting-revealed-tokens)
    - [Updating Metadata](#updating-metadata)
6. [Modifiers](#modifiers)
7. [Security Considerations](#security-considerations)
8. [Usage Examples](#usage-examples)
9. [Events](#events)

---

## Architecture
The `RevealedNFT` contract is designed to:
- Represent a collection of revealed NFTs.
- Allow authorized modules (e.g., reveal strategies) to mint and update metadata.

---

## Dependencies
The contract relies on:
- **ERC721**: Implements the NFT standard.
- **OpenZeppelin Ownable**: Provides access control for the owner.
- **Reveal Strategies**: Integrates with strategies for minting and metadata updates.

---

## State Variables
- `baseURI`: The base URI for token metadata.
- `metadata`: Mapping of token IDs to their metadata.

---

## Core Functionalities

### Minting Revealed Tokens
The `mintRevealed` function allows authorized strategies to mint new revealed tokens.  
- **Requirements**:
  - Only callable by authorized strategies.
  - The token ID must not already exist.

### Updating Metadata
The `updateMetadata` function allows authorized strategies to update the metadata of a token.  
- **Requirements**:
  - Only callable by authorized strategies.
  - The token must exist.

---

## Modifiers
- **onlyAuthorizedStrategy**: Restricts function calls to authorized strategies.

---

## Security Considerations
- **Access Control**: Only authorized strategies can mint tokens and update metadata.
- **Metadata Integrity**: Ensures metadata updates are authorized and valid.

---

## Usage Examples
### Minting a Revealed Token
```solidity
revealedNFT.mintRevealed(toAddress, tokenId, metadata);
```

### Updating Metadata
```solidity
revealedNFT.updateMetadata(tokenId, newMetadata);
```

---

## Events
- **RevealedTokenMinted**: Emitted when a new revealed token is minted.
  - `address indexed to`
  - `uint256 indexed tokenId`
  - `string metadata`
- **MetadataUpdated**: Emitted when a token's metadata is updated.
  - `uint256 indexed tokenId`
  - `string newMetadata`

---
