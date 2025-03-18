# MetadataGenerator Documentation

## Overview
The `MetadataGenerator` library provides utility functions for generating metadata for NFTs. It is used by reveal strategies to create metadata based on randomness provided by Chainlink VRF.

---

## Table of Contents
1. [Overview](#overview)
2. [Functions](#functions)
3. [Usage Examples](#usage-examples)

---

## Functions
### `generateMetadata`
Generates metadata for an NFT based on its token ID and a random number.  
- **Parameters**:
  - `tokenId`: The ID of the NFT.
  - `randomness`: A random number provided by Chainlink VRF.
- **Returns**: A string representing the generated metadata.

---

## Usage Examples
### Generating Metadata
```solidity
string memory metadata = MetadataGenerator.generateMetadata(tokenId, randomness);
```

---
