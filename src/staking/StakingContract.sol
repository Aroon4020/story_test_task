// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol"; // Add ERC721Holder
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; // Add SafeERC20
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IStakingContract.sol";
import "../RevealModule.sol";
import "../utils/Errors.sol";
import "../utils/Events.sol";

contract StakingContract is Ownable, IStakingContract, ERC721Holder {
    using SafeERC20 for ERC20; // Add SafeERC20 usage
    
    ERC20 public rewardToken;
    
    // Reference to the RevealModule for checking revealed status
    RevealModule public revealModule;

    // Track approved NFT contracts
    mapping(address => bool) public approvedNFTContracts;
    
    // 5% APY and seconds in a year constant.
    uint256 public constant APY = 5;
    uint256 public constant SECONDS_IN_YEAR = 365 days;

    struct StakeInfo {
        address owner;
        uint256 tokenId;
        uint256 stakedAt;
        bool staked;
        address nftContract; // Add NFT contract address to track where the token came from
    }

    // Mapping from tokenId to stake info.
    mapping(uint256 => StakeInfo) public stakes;

    constructor(address _rewardToken, address _revealModule, address _owner) Ownable(_owner) {
        rewardToken = ERC20(_rewardToken);
        revealModule = RevealModule(_revealModule);
    }

    /**
     * @notice Update the reveal module address
     * @param _revealModule New reveal module address
     */
    function setRevealModule(address _revealModule) external onlyOwner {
        if (_revealModule == address(0)) revert Errors.ZeroAddress();
        revealModule = RevealModule(_revealModule);
        emit Events.RevealModuleSet(_revealModule);
    }

    /**
     * @notice Add or remove an NFT contract from the approved list
     * @param nftContract Address of the NFT contract
     * @param approved Whether to approve (true) or revoke approval (false)
     */
    function setNFTContractApproval(address nftContract, bool approved) external onlyOwner {
        if (nftContract == address(0)) revert Errors.ZeroAddress();
        approvedNFTContracts[nftContract] = approved;
        emit Events.NFTContractApprovalChanged(nftContract, approved);
    }

    /// @notice Stake a revealed NFT from an approved contract.
    function stake(address nftContract, uint256 tokenId) external override {
        // Check if NFT contract is approved
        if (!approvedNFTContracts[nftContract]) revert Errors.ContractNotApproved(nftContract);
        
        // Check if NFT is revealed through the RevealModule
        if (!revealModule.isRevealed(nftContract, tokenId)) revert Errors.NFTNotRevealed(tokenId);
        
        // Check if caller is the token owner
        if (IERC721(nftContract).ownerOf(tokenId) != msg.sender) 
            revert Errors.NotTokenOwner(msg.sender, tokenId);
        
        // Transfer NFT to this contract
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        
        // Store stake information
        stakes[tokenId] = StakeInfo({
            owner: msg.sender,
            tokenId: tokenId,
            stakedAt: block.timestamp,
            staked: true,
            nftContract: nftContract
        });
        
        emit Events.Staked(msg.sender, tokenId, block.timestamp);
    }

    /// @notice Unstake and claim rewards.
    function unstake(uint256 tokenId) external override {
        StakeInfo storage stakeInfo = stakes[tokenId];
        
        if (!stakeInfo.staked) revert Errors.NotStaked(tokenId);
        if (stakeInfo.owner != msg.sender) revert Errors.NotTokenOwner(msg.sender, tokenId);
        
        uint256 reward = calculateReward(tokenId);
        if (reward > 0) {
            // Use safeTransfer instead of transfer
            rewardToken.safeTransfer(msg.sender, reward);
            emit Events.RewardClaimed(msg.sender, tokenId, reward);
        }
        
        // Mark as unstaked
        stakeInfo.staked = false;
        
        // Use safeTransferFrom for NFT transfers
        IERC721(stakeInfo.nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        
        emit Events.Unstaked(msg.sender, tokenId, block.timestamp);
    }

    /// @notice Calculates accrued reward based on staking duration.
    function calculateReward(uint256 tokenId) public view override returns (uint256) {
        StakeInfo storage stakeInfo = stakes[tokenId];
        
        if (!stakeInfo.staked) revert Errors.NotStaked(tokenId);
        
        uint256 stakingDuration = block.timestamp - stakeInfo.stakedAt;
        // For simplicity, assume a base reward of 1e18 tokens per year per NFT.
        uint256 baseReward = 1e18;
        return (baseReward * APY * stakingDuration) / (100 * SECONDS_IN_YEAR);
    }
}
