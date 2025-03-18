// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRevealStrategy {
    function reveal(address payable nftContract, uint256 tokenId, uint256 randomResult) external returns (bool);
}
