// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Errors
 * @dev Centralized custom errors for all contracts
 */
library Errors {
    // General errors
    error Unauthorized();
    error ZeroAddress();
    error AlreadySet();
    error NotFound();
    error InvalidParameter();

    // NFT specific errors
    error TokenNonexistent(uint256 tokenId);
    error NotTokenOwner(address caller, uint256 tokenId);
    error AlreadyRevealed(uint256 tokenId);
    error InsufficientFunds(uint256 required, uint256 provided);
    error InvalidPaymentAmount(uint256 required, uint256 provided);

    // Reveal Module errors
    error StrategyNotSet(uint256 strategyId);
    error RevealFailed(uint256 tokenId);
    error RevealStrategyInvalid(address strategy);
    error ContractNotApproved(address nftContract);
    error RevealAlreadyPending(uint256 tokenId);  // New error

    // Strategy errors
    error RevealModuleAlreadySet();

    // Staking errors
    error NotStaked(uint256 tokenId);
    error AlreadyStaked(uint256 tokenId);

    // New error for staking checks
    error NFTNotRevealed(uint256 tokenId);

    // Timelock errors
    error TimelockNotExpired(uint256 unlockTime);
}
