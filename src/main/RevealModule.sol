// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
// Remove OpenZeppelin's Ownable to avoid conflicts
import "../strategies/interfaces/IRevealStrategy.sol";
import "./SPNFT.sol";
import "./interfaces/IRevealModule.sol";

// Avoid dual ownership by only using VRFConsumerBaseV2Plus's ownership model
contract RevealModule is VRFConsumerBaseV2Plus, IRevealModule {
    // Changed to be compatible with interface return type
    SPNFT private spNftInstance;
    
    // Changed to be compatible with interface return type
    mapping(uint256 => IRevealStrategy) private revealStrategiesMapping;
    
    // Existing mappings
    mapping(uint256 => uint256) public override tokenToStrategyId;
    mapping(bytes32 => uint256) public override requestIdToTokenId;

    // Chainlink VRF V2 parameters
    bytes32 public override keyHash;
    uint64 public override subscriptionId;
    uint16 public override requestConfirmations;
    uint32 public override callbackGasLimit;
    uint32 public override numWords;
    
    // Default strategy ID
    uint256 public override defaultStrategyId;
    
    // Mapping from VRF request ID to tokenId
    mapping(uint256 => uint256) public requestIdToTokenIdV2;

    // Removed duplicate events since they're defined in the interface

    // Fix constructor to not pass msg.sender to Ownable
    constructor(
        address _spNFT,
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint16 _requestConfirmations,
        uint32 _callbackGasLimit,
        uint32 _numWords,
        uint256 _defaultStrategyId
    )
        VRFConsumerBaseV2Plus(_vrfCoordinator)
    {
        spNftInstance = SPNFT(_spNFT);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        requestConfirmations = _requestConfirmations;
        callbackGasLimit = _callbackGasLimit;
        numWords = _numWords;
        defaultStrategyId = _defaultStrategyId;
    }

    // Interface implementations for public getters
    function spNFT() external view override returns (address) {
        return address(spNftInstance);
    }
    
    function revealStrategies(uint256 strategyId) external view override returns (address) {
        return address(revealStrategiesMapping[strategyId]);
    }

    /// @notice Operator adds or updates a reveal strategy.
    function setRevealStrategy(uint256 strategyId, address strategyAddress) external override onlyOwner {
        revealStrategiesMapping[strategyId] = IRevealStrategy(strategyAddress);
    }

    /// @notice Operator sets the reveal strategy for a particular token.
    function setTokenStrategy(uint256 tokenId, uint256 strategyId) external override onlyOwner {
        require(address(revealStrategiesMapping[strategyId]) != address(0), "Strategy not set");
        tokenToStrategyId[tokenId] = strategyId;
    }

    /// @notice Operator updates the default strategy.
    function setDefaultStrategy(uint256 newDefaultStrategyId) external override onlyOwner {
        require(address(revealStrategiesMapping[newDefaultStrategyId]) != address(0), "Strategy not set");
        defaultStrategyId = newDefaultStrategyId;
    }

    /// @notice Operator triggers a reveal for a specific token.
    function reveal(uint256 tokenId) external override onlyOwner {
        // Updated according to provided pattern
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,  // Changed callBackGasLimit to callbackGasLimit to match our variable name
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: false  // Not using native payment for this example
                    })
                )
            })
        );
        
        requestIdToTokenIdV2[requestId] = tokenId;
        emit RandomWordsRequestSent(requestId, tokenId);
    }
    
    /// @notice Callback function used by Chainlink VRF V2 to deliver randomness.
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 tokenId = requestIdToTokenIdV2[requestId];
        // Determine which strategy to use; fallback to default if none is set
        uint256 strategyId = tokenToStrategyId[tokenId];
        if (strategyId == 0) {
            strategyId = defaultStrategyId;
        }
        IRevealStrategy strategy = revealStrategiesMapping[strategyId];
        require(address(strategy) != address(0), "Reveal strategy not set");
        
        // Use the first random word for the reveal
        bool success = strategy.reveal(tokenId, randomWords[0]);
        require(success, "Reveal strategy execution failed");
        
        emit RevealSuccessful(tokenId, randomWords[0]);
    }
    
    /// @notice Updates the Chainlink VRF parameters
    function updateVRFParameters(
        bytes32 _keyHash,
        uint64 _subscriptionId,
        uint16 _requestConfirmations,
        uint32 _callbackGasLimit,
        uint32 _numWords
    ) external onlyOwner {
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        requestConfirmations = _requestConfirmations;
        callbackGasLimit = _callbackGasLimit;
        numWords = _numWords;
    }
}