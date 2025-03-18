// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ---------- External Imports ----------
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// ---------- Internal Imports ----------
import "../interfaces/IStakingContract.sol";
import "../RevealModule.sol";
import "../utils/Errors.sol";
import "../utils/Events.sol";

/**
 * @title StakingContract
 * @notice Allows NFT staking with reward accrual based on staking duration.
 * @dev Uses a constant APY and on-chain reward calculation.
 */
contract StakingContract is Ownable, IStakingContract, ERC721Holder, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    // ---------- Type Declarations ----------
    /**
     * @dev Information about an NFT stake.
     * Packed into one 32-byte slot:
     * - owner: 20 bytes
     * - stakedAt: 12 bytes (uint96)
     */
    struct StakeInfo {
        address owner;
        uint96 stakedAt;
    }

    // ---------- State Variables ----------
    // Constants
    uint256 public constant APY = 5;
    uint256 public constant SECONDS_IN_YEAR = 365 days;
    
    // Immutable variables
    IERC20Metadata public immutable rewardToken;
    
    // Regular state variables
    RevealModule public revealModule;
    
    // ---------- Mappings ----------
    mapping(address => bool) public approvedNFTContracts;
    mapping(bytes32 => StakeInfo) public stakes;

    // ---------- Constructor ----------
    /**
     * @notice Initializes the staking contract.
     * @param _rewardToken Address of the reward token contract.
     * @param _revealModule Address of the reveal module contract.
     * @param _owner Owner address for this contract.
     */
    constructor(
        address _rewardToken,
        address _revealModule,
        address _owner
    ) Ownable(_owner) {
        // Set reward token (using IERC20Metadata for decimal support)
        rewardToken = IERC20Metadata(_rewardToken);
        // Initialize the reveal module contract
        revealModule = RevealModule(_revealModule);
    }

    // ---------- External Non-View Functions ----------
    /**
     * @notice Sets a new reveal module.
     * @param _revealModule Address of the new reveal module.
     * @dev Reverts if _revealModule is the zero address.
     */
    function setRevealModule(address _revealModule) external override onlyOwner {
        if (_revealModule == address(0)) revert Errors.ZeroAddress();
        revealModule = RevealModule(_revealModule);
        emit Events.RevealModuleSet(_revealModule);
    }

    /**
     * @notice Approves or revokes an NFT contract for staking.
     * @param nftContract Address of the NFT contract.
     * @param approved True to approve, false to revoke.
     * @dev Reverts if nftContract is the zero address.
     */
    function setNFTContractApproval(address nftContract, bool approved) external override onlyOwner {
        if (nftContract == address(0)) revert Errors.ZeroAddress();
        approvedNFTContracts[nftContract] = approved;
        emit Events.NFTContractApprovalChanged(nftContract, approved);
    }

    /**
     * @notice Stakes an NFT by transferring it to this contract.
     * @param nftContract Address of the NFT contract.
     * @param tokenId The token ID to stake.
     * @dev Reverts if the NFT contract is not approved or if the NFT has not been revealed.
     */
    function stake(address nftContract, uint256 tokenId) external override nonReentrant {
        if (!approvedNFTContracts[nftContract]) revert Errors.ContractNotApproved(nftContract);
        if (!revealModule.isRevealed(nftContract, tokenId)) revert Errors.NFTNotRevealed(tokenId);
        
        bytes32 stakeKey = _getStakeKey(nftContract, tokenId);
        // Transfer the NFT from the staker to this contract.
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        // Record staking information using packed StakeInfo.
        stakes[stakeKey] = StakeInfo(msg.sender, uint96(block.timestamp));
        
        emit Events.Staked(msg.sender, tokenId, block.timestamp);
    }

    /**
     * @notice Unstakes an NFT, returning it to the owner.
     * @param nftContract Address of the NFT contract.
     * @param tokenId The token ID to unstake.
     * @dev Reverts if the caller is not the original staker.
     */
    function unstake(address nftContract, uint256 tokenId) external override nonReentrant {
        bytes32 stakeKey = _getStakeKey(nftContract, tokenId);
        StakeInfo memory stakeInfo = stakes[stakeKey];
        if (stakeInfo.owner != msg.sender) revert Errors.NotTokenOwner(msg.sender, tokenId);
        
        delete stakes[stakeKey];
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        
        emit Events.Unstaked(msg.sender, tokenId, block.timestamp);
    }

    /**
     * @notice Unstakes an NFT and claims the accrued reward.
     * @param nftContract Address of the NFT contract.
     * @param tokenId The token ID to unstake.
     * @dev Calculates reward based on staking duration and transfers reward tokens.
     */
    function unstakeAndClaimReward(address nftContract, uint256 tokenId) external override nonReentrant {
        bytes32 stakeKey = _getStakeKey(nftContract, tokenId);
        StakeInfo memory stakeInfo = stakes[stakeKey];
        if (stakeInfo.owner != msg.sender) revert Errors.NotTokenOwner(msg.sender, tokenId);
        
        uint256 reward = calculateReward(stakeInfo.stakedAt);
        delete stakes[stakeKey];
        if (reward > 0) {
            rewardToken.safeTransfer(msg.sender, reward);
        }
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        emit Events.Unstaked(msg.sender, tokenId, block.timestamp);
    }

    /**
     * @notice Claims reward for a staked NFT without unstaking.
     * @param nftContract Address of the NFT contract.
     * @param tokenId The token ID for which to claim the reward.
     * @dev Updates the stakedAt timestamp to reset reward accrual.
     */
    function claimReward(address nftContract, uint256 tokenId) external override nonReentrant {
        bytes32 stakeKey = _getStakeKey(nftContract, tokenId);
        StakeInfo storage stakeInfo = stakes[stakeKey];
        if (stakeInfo.owner != msg.sender) revert Errors.NotTokenOwner(msg.sender, tokenId);
        
        uint256 reward = calculateReward(stakeInfo.stakedAt);
        if (reward > 0) {
            // Reset the staking timestamp to current time.
            stakeInfo.stakedAt = uint96(block.timestamp);
            rewardToken.safeTransfer(msg.sender, reward);
        }
        emit Events.RewardClaimed(msg.sender, tokenId, reward);
    }

    /**
     * @notice Deposits reward tokens into the contract.
     * @param amount The amount of reward tokens to deposit.
     */
    function depositReward(uint256 amount) external override nonReentrant {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Events.RewardAdded(msg.sender, amount);
    }

    // ---------- External View Functions ----------
    /**
     * @notice Retrieves staking information for a given NFT.
     * @param nftContract Address of the NFT contract.
     * @param tokenId The token ID.
     * @return owner The address of the staker.
     * @return stakedAt The timestamp when staking began.
     */
    function getStakeInfo(address nftContract, uint256 tokenId)
        external
        view
        override
        returns (address owner, uint96 stakedAt)
    {
        bytes32 stakeKey = _getStakeKey(nftContract, tokenId);
        StakeInfo storage info = stakes[stakeKey];
        return (info.owner, info.stakedAt);
    }

    // ---------- Public View Functions ----------
    /**
     * @notice Calculates the reward based on the staking duration.
     * @param stakedAt The timestamp when staking began.
     * @return The calculated reward amount.
     * @dev Uses token decimals, APY, and a constant for seconds per year.
     */
    function calculateReward(uint96 stakedAt) public view override returns (uint256) {
        uint256 stakingDuration = block.timestamp - stakedAt;
        // Calculate reward using APY; scaling factor 10**rewardToken.decimals() ensures proper decimal adjustment.
        return (10 ** rewardToken.decimals() * APY * stakingDuration) / (100 * SECONDS_IN_YEAR);
    }

    // ---------- Internal Functions ----------
    /**
     * @notice Generates a unique key for a stake using the NFT contract address and token ID.
     * @param nftContract The address of the NFT contract.
     * @param tokenId The token ID.
     * @return A bytes32 hash uniquely identifying the stake.
     */
    function _getStakeKey(address nftContract, uint256 tokenId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(nftContract, tokenId));
    }
}
