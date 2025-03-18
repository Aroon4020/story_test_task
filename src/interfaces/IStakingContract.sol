// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IStakingContract {
    function setRevealModule(address _revealModule) external;
    function setNFTContractApproval(address nftContract, bool approved) external;
    function stake(address nftContract, uint256 tokenId) external;
    function unstake(address nftContract, uint256 tokenId) external;
    function unstakeAndClaimReward(address nftContract, uint256 tokenId) external;
    function claimReward(address nftContract, uint256 tokenId) external;
    function calculateReward(uint96 stakedAt) external view returns (uint256);
    function getStakeInfo(address nftContract, uint256 tokenId) external view returns (address owner, uint96 stakedAt);
    function depositReward(uint256 amount) external;
}
