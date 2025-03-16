// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IStakingContract {
    function stake(address nftContract, uint256 tokenId) external;
    function unstake(uint256 tokenId) external;
    function calculateReward(uint256 tokenId) external view returns (uint256);
}
