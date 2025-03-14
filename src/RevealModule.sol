// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "./interfaces/IRevealStrategy.sol";
import "./SPNFT.sol";
import "./interfaces/IRevealModule.sol";
import "./helpers/Errors.sol";
import "./helpers/Events.sol";

// Avoid dual ownership by only using VRFConsumerBaseV2Plus's ownership model
contract RevealModule is VRFConsumerBaseV2Plus, IRevealModule {
    // Changed to be compatible with interface return type
    SPNFT private spNftInstance;
    
    // Changed to be compatible with interface return type
    mapping(uint256 => IRevealStrategy) private revealStrategiesMapping;
    
    // Existing mappings
    mapping(uint256 => uint256) public  tokenToStrategyId;
    mapping(uint256 => uint256) public  requestIdToTokenId;

    // Chainlink VRF V2 parameters
    bytes32 public  keyHash;
    uint64 public  subscriptionId;
    uint16 public  requestConfirmations;
    uint32 public  callbackGasLimit;
    uint32 public  numWords;
    
    // Default strategy ID
    uint256 public  defaultStrategyId;

    // Fix constructor to not pass msg.sender to Ownable
    constructor(
        address payable _spNFT,  
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
    function spNFT() external view  returns (address) {
        return address(spNftInstance);
    }
    
    function revealStrategies(uint256 strategyId) external view  returns (address) {
        return address(revealStrategiesMapping[strategyId]);
    }

    /// @notice Operator adds or updates a reveal strategy.
    function setRevealStrategy(uint256 strategyId, address strategyAddress) external override onlyOwner {
        if (strategyAddress == address(0)) revert Errors.ZeroAddress();
        revealStrategiesMapping[strategyId] = IRevealStrategy(strategyAddress);
        emit Events.RevealStrategySet(strategyId, strategyAddress);
    }

    /// @notice Operator sets the reveal strategy for a particular token.
    function setTokenStrategy(uint256 tokenId, uint256 strategyId) external override onlyOwner {
        if (address(revealStrategiesMapping[strategyId]) == address(0)) 
            revert Errors.StrategyNotSet(strategyId);
        tokenToStrategyId[tokenId] = strategyId;
        emit Events.TokenStrategySet(tokenId, strategyId);
    }

    /// @notice Operator updates the default strategy.
    function setDefaultStrategy(uint256 newDefaultStrategyId) external override onlyOwner {
        if (address(revealStrategiesMapping[newDefaultStrategyId]) == address(0)) 
            revert Errors.StrategyNotSet(newDefaultStrategyId);
        defaultStrategyId = newDefaultStrategyId;
        emit Events.DefaultStrategySet(newDefaultStrategyId);
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
        
        requestIdToTokenId[requestId] = tokenId;
        emit RandomWordsRequestSent(requestId, tokenId);
    }
    
    /// @notice Callback function used by Chainlink VRF V2 to deliver randomness.
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 tokenId = requestIdToTokenId[requestId];
        // Determine which strategy to use; fallback to default if none is set
        uint256 strategyId = tokenToStrategyId[tokenId];
        if (strategyId == 0) {
            strategyId = defaultStrategyId;
        }
        IRevealStrategy strategy = revealStrategiesMapping[strategyId];
        if (address(strategy) == address(0)) revert Errors.StrategyNotSet(strategyId);
        
        // Use the first random word for the reveal
        bool success = strategy.reveal(tokenId, randomWords[0]);
        if (!success) revert Errors.RevealFailed(tokenId);
        
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
        emit Events.VRFParametersUpdated(_keyHash, _subscriptionId, _requestConfirmations, _callbackGasLimit, _numWords);
    }
}