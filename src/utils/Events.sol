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
    event ApprovedStrategySet(address indexed strategyAddress);
    
    // RevealedNFT events
    event RevealedNFTMinted(address indexed to, uint256 indexed tokenId);
    
    // RevealModule events
    event RevealStrategySet(uint256 indexed strategyId, address indexed strategyAddress);
    event TokenStrategySet(uint256 indexed tokenId, uint256 indexed strategyId);
    event DefaultStrategySet(uint256 indexed strategyId);
    event VRFParametersUpdated(bytes32 keyHash, uint64 subscriptionId, uint16 requestConfirmations, uint32 callbackGasLimit, uint32 numWords);
    event CallbackGasLimitUpdated(uint32 callbackGasLimit); // New event for focused gas limit updates
    event RandomWordsRequestSent(uint256 requestId, address indexed nftContract, uint256 tokenId);
    event RevealSuccessful(address indexed nftContract, uint256 indexed tokenId, uint256 randomness);
    event NFTContractApprovalChanged(address indexed nftContract, bool approved);
    
    // Add new events for direct strategy management
    event RevealStrategySet(address indexed strategyAddress);
    event StrategyApprovalChanged(address indexed strategy, bool approved);

    // RevealStrategy events
    event RevealModuleSetForStrategy(address indexed moduleAddress);
    event TokenRevealExecuted(uint256 indexed tokenId, uint256 randomness);
    event TokenBurnedAndMinted(uint256 indexed tokenId, address indexed owner, string metadata);
    
    // Staking events 
    event Staked(address indexed owner, uint256 indexed tokenId, uint256 timestamp);
    event Unstaked(address indexed owner, uint256 indexed tokenId, uint256 timestamp);
    event RewardClaimed(address indexed owner, uint256 indexed tokenId, uint256 amount);
    event RewardAdded(address indexed from, uint256 amount);
    event RewardWithdrawn(address indexed to, uint256 amount);

    // Strategy update events
    event StrategyUpdateScheduled(address indexed newStrategy, uint256 activationTime);
    event StrategyUpdated(address indexed strategy);
    event StrategyUpdateCancelled(address indexed cancelledStrategy);
}
