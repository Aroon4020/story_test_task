// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRevealModule {
    // Timelock-based strategy management
    function scheduleStrategyUpdate(address newStrategy) external;
    function cancelStrategyUpdate(address newStrategy) external;
    
    // Reveal functionality - removed backward compatibility function
    function reveal(address nftContract, uint256 tokenId) external;
    
    event RandomWordsRequestSent(uint256 requestId, address indexed nftContract, uint256 tokenId);
    event RevealSuccessful(address indexed nftContract, uint256 indexed tokenId, uint256 randomness);
}
