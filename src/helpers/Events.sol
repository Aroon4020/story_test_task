// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Events
 * @dev Centralized events for all contracts
 */
library Events {
    // SPNFT events
    event RevealModuleSet(address indexed moduleAddress);
    event MintPriceUpdated(uint256 newPrice);
    event TokenMinted(address indexed to, uint256 indexed tokenId);
    event TokenRevealed(uint256 indexed tokenId, string metadata);
    event TokenBurned(address indexed owner, uint256 indexed tokenId);
    event ETHWithdrawn(address indexed to, uint256 amount);
    
    // RevealedNFT events
    event RevealedNFTMinted(address indexed to, uint256 indexed tokenId);
    
    // RevealModule events
    event RevealStrategySet(uint256 indexed strategyId, address indexed strategyAddress);
    event TokenStrategySet(uint256 indexed tokenId, uint256 indexed strategyId);
    event DefaultStrategySet(uint256 indexed strategyId);
    event VRFParametersUpdated(bytes32 keyHash, uint64 subscriptionId, uint16 requestConfirmations, uint32 callbackGasLimit, uint32 numWords);
    event RandomWordsRequestSent(uint256 requestId, uint256 tokenId);
    event RevealSuccessful(uint256 indexed tokenId, uint256 randomness);
    
    // RevealStrategy events
    event RevealModuleSetForStrategy(address indexed moduleAddress);
    event TokenRevealExecuted(uint256 indexed tokenId, uint256 randomness);
    event TokenBurnedAndMinted(uint256 indexed tokenId, address indexed owner, string metadata);
    
    // Staking events 
    event Staked(address indexed owner, uint256 indexed tokenId, uint256 timestamp);
    event Unstaked(address indexed owner, uint256 indexed tokenId, uint256 timestamp);
    event RewardClaimed(address indexed owner, uint256 indexed tokenId, uint256 amount);
}
