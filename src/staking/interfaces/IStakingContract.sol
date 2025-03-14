// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IStakingContract {
    // struct StakeInfo {
    //     address owner;
    //     uint256 tokenId;
    //     uint256 stakedAt;
    //     bool staked;
    // }
    
    // event Staked(address indexed owner, uint256 tokenId, uint256 timestamp);
    // event Unstaked(address indexed owner, uint256 tokenId, uint256 timestamp);
    // event RewardClaimed(address indexed owner, uint256 tokenId, uint256 reward);
    
    //function revealedNFT() external view returns (address);
    //function rewardToken() external view returns (address);
    //function stakes(uint256 tokenId) external view returns (address owner, uint256 id, uint256 stakedAt, bool staked);
    
    function stake(uint256 tokenId) external;
    function unstake(uint256 tokenId) external;
    function calculateReward(uint256 tokenId) external view returns (uint256);
}
