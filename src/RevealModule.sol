// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IRevealStrategy.sol";
import "./interfaces/IRevealModule.sol";
import "./utils/Errors.sol" as CustomErrors;  // Use alias to avoid conflict
import "./utils/Events.sol";

/**
 * @title RevealModule
 * @notice Manages NFT reveal with Chainlink VRF and timelock-protected strategy updates
 */
contract RevealModule is VRFConsumerBaseV2Plus, IRevealModule {
    // Timelock controller for strategy updates
    TimelockController public timelock;
    
    // Single strategy pattern
    IRevealStrategy public revealStrategy;
    
    // Optimized struct - packed into a single 32-byte slot
    struct RevealRequest {
        address nftContract;  // 20 bytes
        uint96 tokenId;       // 12 bytes
        // Total: 32 bytes (1 storage slot)
    }
    
    // Map requestId to reveal request details
    mapping(uint256 => RevealRequest) public revealRequests;

    // Chainlink VRF V2 parameters
    bytes32 public keyHash;
    uint64 public subscriptionId;
    uint16 public requestConfirmations;
    uint32 public callbackGasLimit;
    uint32 public numWords;

    // Strategy update operation identifier
    bytes32 public constant STRATEGY_UPDATE_OPERATION = keccak256("STRATEGY_UPDATE");
    
    // Track approved NFT contracts
    mapping(address => bool) public approvedNFTContracts;

    // Define enum for reveal status tracking
    enum RevealStatus {
        NotRequested,  // Initial state, reveal never requested
        RequestPending, // Reveal requested but not completed
        Revealed       // Reveal completed
    }
    
    // Track revealed NFTs using a single mapping with combined key hash
    mapping(bytes32 => RevealStatus) public revealStatus;
    
    constructor(
        address _vrfCoordinator,
        address _strategy,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint16 _requestConfirmations,
        uint32 _callbackGasLimit,
        uint32 _numWords,
        uint256 _timelockDelay,
        address _owner
    )
        VRFConsumerBaseV2Plus(_vrfCoordinator)
    {
        
        // Initialize the timelock
        address[] memory proposers = new address[](1);
        proposers[0] = _owner;  // Owner as proposer
        
        address[] memory executors = new address[](1);
        executors[0] = address(0);  // Zero address means anyone can execute
        
        timelock = new TimelockController(
            _timelockDelay,
            proposers,
            executors,
            _owner  // Admin
        );
        
        revealStrategy = IRevealStrategy(_strategy);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        requestConfirmations = _requestConfirmations;
        callbackGasLimit = _callbackGasLimit;
        numWords = _numWords;
    }
    
    /**
     * @notice Schedule a strategy update using the timelock controller
     * @param newStrategy The address of the new strategy contract
     */
    function scheduleStrategyUpdate(address newStrategy) external override onlyOwner {
        if (newStrategy == address(0)) revert CustomErrors.Errors.ZeroAddress();
        
        // Encode the function call to update the strategy
        bytes memory data = abi.encodeWithSelector(
            this.executeStrategyUpdate.selector,
            newStrategy
        );
        
        // Schedule the operation in the timelock
        timelock.schedule(
            address(this),               // Target (this contract)
            0,                           // Value (no ETH)
            data,                        // Data (function call)
            bytes32(0),                  // Predecessor (none)
            STRATEGY_UPDATE_OPERATION,   // Salt for operation identification
            timelock.getMinDelay()       // Delay
        );
        
        emit Events.StrategyUpdateScheduled(newStrategy, block.timestamp + timelock.getMinDelay());
    }
    
    /**
     * @notice Execute a scheduled strategy update - can only be called through the timelock
     * @param newStrategy The address of the new strategy contract
     */
    function executeStrategyUpdate(address newStrategy) external {
        // Only the timelock can call this function
        if (msg.sender != address(timelock)) revert CustomErrors.Errors.Unauthorized();
        
        // Update the strategy
        revealStrategy = IRevealStrategy(newStrategy);
        emit Events.StrategyUpdated(newStrategy);
    }
    
    /**
     * @notice Cancel a scheduled strategy update
     * @param newStrategy The strategy address used in the original scheduling
     */
    function cancelStrategyUpdate(address newStrategy) external override onlyOwner {
        // Encode the function call that was scheduled
        bytes memory data = abi.encodeWithSelector(
            this.executeStrategyUpdate.selector,
            newStrategy
        );
        
        timelock.cancel(
            bytes32(keccak256(abi.encode(
                address(this),               // Target
                0,                           // Value
                data,                        // Data
                bytes32(0),                  // Predecessor
                STRATEGY_UPDATE_OPERATION    // Salt
            )))
        );
        
        emit Events.StrategyUpdateCancelled(newStrategy);
    }

    /**
     * @notice Add or remove an NFT contract from the approved list
     * @param nftContract Address of the NFT contract
     * @param approved Whether to approve (true) or revoke approval (false)
     */
    function setNFTContractApproval(address nftContract, bool approved) external onlyOwner {
        if (nftContract == address(0)) revert CustomErrors.Errors.ZeroAddress();
        approvedNFTContracts[nftContract] = approved;
        emit Events.NFTContractApprovalChanged(nftContract, approved);
    }
    
    /**
     * @notice Generates a unique key for an NFT by hashing contract address and token ID
     * @param nftContract Address of the NFT contract
     * @param tokenId ID of the token
     * @return A unique bytes32 identifier
     */
    function _getNFTKey(address nftContract, uint256 tokenId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(nftContract, tokenId));
    }
    
    /**
     * @notice Check if a specific NFT has been revealed
     * @param nftContract Address of the NFT contract
     * @param tokenId ID of the token
     * @return Status of the NFT's reveal process
     */
    function getRevealStatus(address nftContract, uint256 tokenId) external view returns (RevealStatus) {
        return revealStatus[_getNFTKey(nftContract, tokenId)];
    }
    
    /**
     * @notice Check if a specific NFT has been revealed
     * @param nftContract Address of the NFT contract
     * @param tokenId ID of the token
     * @return Whether the NFT has been revealed
     */
    function isRevealed(address nftContract, uint256 tokenId) external view returns (bool) {
        return revealStatus[_getNFTKey(nftContract, tokenId)] == RevealStatus.Revealed;
    }
    
    /**
     * @notice Request randomness for a token reveal, works with approved NFT contracts only
     * @param nftContract Address of the ERC721 contract
     * @param tokenId The token to reveal
     */
    function reveal(address nftContract, uint256 tokenId) external override {
        // Check that the NFT isn't already revealed or pending
        bytes32 nftKey = _getNFTKey(nftContract, tokenId);
        if (revealStatus[nftKey] != RevealStatus.NotRequested) {
            if (revealStatus[nftKey] == RevealStatus.Revealed)
                revert CustomErrors.Errors.AlreadyRevealed(tokenId);
            else
                revert CustomErrors.Errors.RevealAlreadyPending(tokenId);
        }
        
        // Check that the contract is approved
        if (!approvedNFTContracts[nftContract]) revert CustomErrors.Errors.ContractNotApproved(nftContract);
        
        // Check that the caller is the owner of the specified token in the specified contract
        if (nftContract == address(0)) revert CustomErrors.Errors.ZeroAddress();
        if (IERC721(nftContract).ownerOf(tokenId) != msg.sender) 
            revert CustomErrors.Errors.NotTokenOwner(msg.sender, tokenId);
        if (address(revealStrategy) == address(0)) revert CustomErrors.Errors.StrategyNotSet(0);
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: true
                    })
                )
            })
        );
        
        // Store both contract address and token ID - using uint96 for tokenId
        // This is safe as 2^96 ≈ 7.9e28, which is far larger than practical token ID values
        revealRequests[requestId] = RevealRequest({
            nftContract: nftContract,
            tokenId: uint96(tokenId) // Safe conversion as token IDs are typically much smaller than 2^96
        });
        
        // Mark as pending
        revealStatus[nftKey] = RevealStatus.RequestPending;
        
        emit RandomWordsRequestSent(requestId, nftContract, tokenId);
    }
    
    // Internal functions
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        RevealRequest memory request = revealRequests[requestId];
        // Use the first random word for the reveal - convert token ID back to uint256
        bool success = revealStrategy.reveal(payable(request.nftContract), uint256(request.tokenId), randomWords[0]);
        if (!success) revert CustomErrors.Errors.RevealFailed(request.tokenId);
        
        // Mark the NFT as revealed
        bytes32 nftKey = _getNFTKey(request.nftContract, uint256(request.tokenId));
        revealStatus[nftKey] = RevealStatus.Revealed;
        
        emit RevealSuccessful(request.nftContract, request.tokenId, randomWords[0]);
        
        // Clean up storage
        delete revealRequests[requestId];
    }
}