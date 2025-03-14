// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IStakingContract.sol";

contract StakingContract is Ownable, IStakingContract {
    IERC721 public revealedNFT;
    ERC20 public rewardToken;

    // 5% APY and seconds in a year constant.
    uint256 public constant APY = 5;
    uint256 public constant SECONDS_IN_YEAR = 365 days;

    struct StakeInfo {
        address owner;
        uint256 tokenId;
        uint256 stakedAt;
        bool staked;
    }

    // Mapping from tokenId to stake info.
    mapping(uint256 => StakeInfo) public stakes;

    event Staked(address indexed owner, uint256 tokenId, uint256 timestamp);
    event Unstaked(address indexed owner, uint256 tokenId, uint256 timestamp);
    event RewardClaimed(address indexed owner, uint256 tokenId, uint256 reward);

    constructor(address _revealedNFT, address _rewardToken) Ownable(msg.sender) {
        revealedNFT = IERC721(_revealedNFT);
        rewardToken = ERC20(_rewardToken);
    }

    /// @notice Stake a revealed NFT.
    function stake(uint256 tokenId) external override {
        require(revealedNFT.ownerOf(tokenId) == msg.sender, "Not token owner");
        // Transfer NFT to this contract.
        revealedNFT.transferFrom(msg.sender, address(this), tokenId);
        stakes[tokenId] = StakeInfo({
            owner: msg.sender,
            tokenId: tokenId,
            stakedAt: block.timestamp,
            staked: true
        });
        emit Staked(msg.sender, tokenId, block.timestamp);
    }

    /// @notice Unstake and claim rewards.
    function unstake(uint256 tokenId) external override {
        StakeInfo storage stakeInfo = stakes[tokenId];
        require(stakeInfo.staked, "Not staked");
        require(stakeInfo.owner == msg.sender, "Not token owner");
        uint256 reward = calculateReward(tokenId);
        if (reward > 0) {
            rewardToken.transfer(msg.sender, reward);
            emit RewardClaimed(msg.sender, tokenId, reward);
        }
        stakeInfo.staked = false;
        revealedNFT.transferFrom(address(this), msg.sender, tokenId);
        emit Unstaked(msg.sender, tokenId, block.timestamp);
    }

    /// @notice Calculates accrued reward based on staking duration.
    function calculateReward(uint256 tokenId) public view override returns (uint256) {
        StakeInfo storage stakeInfo = stakes[tokenId];
        require(stakeInfo.staked, "Not staked");
        uint256 stakingDuration = block.timestamp - stakeInfo.stakedAt;
        // For simplicity, assume a base reward of 1e18 tokens per year per NFT.
        uint256 baseReward = 1e18;
        return (baseReward * APY * stakingDuration) / (100 * SECONDS_IN_YEAR);
    }
}
