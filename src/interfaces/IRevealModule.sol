// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRevealModule {
    
    function setRevealStrategy(uint256 strategyId, address strategyAddress) external;
    function setTokenStrategy(uint256 tokenId, uint256 strategyId) external;
    function setDefaultStrategy(uint256 newDefaultStrategyId) external;
    function reveal(uint256 tokenId) external;
    
    event RandomWordsRequestSent(uint256 requestId, uint256 tokenId);
    event RevealSuccessful(uint256 tokenId, uint256 randomness);
}
