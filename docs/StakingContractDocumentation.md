# Staking Contract Documentation

## Overview
This document explains the design, functionality, and usage of the `StakingContract`. The contract allows users to stake approved NFTs in exchange for reward tokens that accrue over time based on a constant APY. Reward calculation is performed on-chain using staking duration and the token's decimals.

---

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Dependencies](#dependencies)
4. [Contract Structure](#contract-structure)
5. [State Variables and Mappings](#state-variables-and-mappings)
6. [Core Functionalities](#core-functionalities)
    - [Staking NFTs](#staking-nfts)
    - [Unstaking and Claiming Rewards](#unstaking-and-claiming-rewards)
    - [Reward Calculation](#reward-calculation)
7. [Administrative Functions](#administrative-functions)
8. [Security Considerations](#security-considerations)
9. [Usage Examples](#usage-examples)
10. [Events](#events)

---

## Architecture
The `StakingContract` is designed to:
- Allow users to stake NFTs approved by the contract.
- Accumulate rewards for staked NFTs based on a fixed APY.
- Enable users to claim rewards and unstake their NFTs.

---

## Dependencies
The contract relies on:
- **ERC721**: For NFT staking and ownership verification.
- **ERC20**: For reward token distribution.
- **OpenZeppelin Contracts**: For safe math operations and access control.

---

## Contract Structure
The contract is structured as follows:
- **State Variables**: Tracks staked NFTs, rewards, and user balances.
- **Core Functions**: Handles staking, unstaking, and reward calculations.
- **Administrative Function**: Allows the owner to set approved NFTs.

---

## State Variables and Mappings
### Key Variables
- `rewardToken`: Address of the ERC20 reward token.
- `apy`: Annual percentage yield for rewards.
- `stakedNFTs`: Mapping of user addresses to their staked NFT IDs.
- `stakeTimestamps`: Mapping of NFT IDs to their staking start timestamps.

### Mappings
- `userRewards`: Tracks accrued rewards for each user.
- `approvedNFTs`: Tracks which NFT contracts are allowed for staking.

---

## Core Functionalities

### Staking NFTs
Users can stake NFTs by calling the `stake` function:
- **Requirements**:
  - The NFT must be approved for transfer by the contract.
  - The NFT contract must be in the `approvedNFTs` list.
- **Process**:
  - Transfers the NFT to the contract.
  - Records the staking timestamp.
  - Updates the user's staked NFT list.

### Unstaking and Claiming Rewards
Users can unstake their NFTs and claim rewards by calling `unstake`:
- **Requirements**:
  - The NFT must be currently staked by the user.
- **Process**:
  - Calculates the rewards based on staking duration.
  - Transfers the NFT back to the user.
  - Updates the user's reward balance.

### Reward Calculation
Rewards are calculated using the formula:
```
rewards = (stakingDuration * apy * tokenDecimals) / (365 * 24 * 60 * 60)
```
- **Inputs**:
  - `stakingDuration`: Time (in seconds) the NFT has been staked.
  - `apy`: Annual percentage yield.
  - `tokenDecimals`: Decimals of the reward token.

---

## Administrative Functions
- **approveNFT**: Adds an NFT contract to the approved list.

---

## Security Considerations
- **Reentrancy**: Uses `nonReentrant` modifier to prevent reentrancy attacks.
- **Access Control**: Only the owner can call administrative functions.
- **Overflow/Underflow**: Uses safe math operations to prevent calculation errors.

---

## Usage Examples
### Staking an NFT
```solidity
stakingContract.stake(nftContractAddress, tokenId);
```

### Unstaking and Claiming Rewards
```solidity
stakingContract.unstake(nftContractAddress, tokenId);
```

### Checking Rewards
```solidity
uint256 rewards = stakingContract.calculateRewards(userAddress, tokenId);
```

---

## Events
- **Staked**: Emitted when a user stakes an NFT.
  - `address indexed user`
  - `address indexed nftContract`
  - `uint256 indexed tokenId`
- **Unstaked**: Emitted when a user unstakes an NFT.
  - `address indexed user`
  - `address indexed nftContract`
  - `uint256 indexed tokenId`
- **RewardsClaimed**: Emitted when a user claims rewards.
  - `address indexed user`
  - `uint256 amount`

---

