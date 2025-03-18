// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRevealModule {
    function scheduleStrategyUpdate(address newStrategy) external;
    function executeStrategyUpdate(address newStrategy) external;
    function cancelStrategyUpdate(address newStrategy) external;
    function reveal(address nftContract, uint256 tokenId) external;
    function setNFTContractApproval(address nftContract, bool approved) external;
}
