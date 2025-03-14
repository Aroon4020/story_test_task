// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRevealModule {
    function spNFT() external view returns (address);
    function revealStrategies(uint256 strategyId) external view returns (address);
    function tokenToStrategyId(uint256 tokenId) external view returns (uint256);
    function requestIdToTokenId(bytes32 requestId) external view returns (uint256);
    function defaultStrategyId() external view returns (uint256);
    
    // VRF V2+ related parameters
    function keyHash() external view returns (bytes32);
    function subscriptionId() external view returns (uint64);
    function requestConfirmations() external view returns (uint16);
    function callbackGasLimit() external view returns (uint32);
    function numWords() external view returns (uint32);
    
    function setRevealStrategy(uint256 strategyId, address strategyAddress) external;
    function setTokenStrategy(uint256 tokenId, uint256 strategyId) external;
    function setDefaultStrategy(uint256 newDefaultStrategyId) external;
    function reveal(uint256 tokenId) external;
    
    event RandomWordsRequestSent(uint256 requestId, uint256 tokenId);
    event RevealSuccessful(uint256 tokenId, uint256 randomness);
}
