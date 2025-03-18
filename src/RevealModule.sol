// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ---------- Imports ----------
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IRevealStrategy.sol";
import "./interfaces/IRevealModule.sol";
import "./utils/Errors.sol" as CustomErrors;
import "./utils/Events.sol";

// ---------- Type Declarations ----------

/**
 * @dev Packed struct for storing NFT reveal request details.
 * The fields are carefully chosen to pack into one 32-byte slot:
 * - nftContract (20 bytes)
 * - tokenId (12 bytes, using uint96)
 */
struct RevealRequest {
    address nftContract;
    uint96 tokenId;
}

/**
 * @dev Enum to track the reveal status of an NFT.
 */
enum RevealStatus {
    NotRequested,   // Reveal never requested
    RequestPending, // Reveal requested but not yet completed
    Revealed        // Reveal completed
}

// ---------- Contract Declaration ----------
/**
 * @title RevealModule
 * @notice Manages NFT reveal with Chainlink VRF and timelock-protected strategy updates.
 */
contract RevealModule is VRFConsumerBaseV2Plus, IRevealModule {
    // ---------- State Variables ----------

    // Constants (declared first)
    bytes32 public constant STRATEGY_UPDATE_OPERATION = keccak256("STRATEGY_UPDATE");

    // Immutable variables (assigned once in constructor)
    bytes32 public immutable keyHash;
    uint64 public immutable subscriptionId;
    uint32 public immutable numWords;

    // Regular state variables
    TimelockController public timelock;      // Timelock controller for strategy updates
    IRevealStrategy public revealStrategy;   // Current reveal strategy
    uint16 public requestConfirmations;      // VRF request confirmations (modifiable)
    uint32 public callbackGasLimit;          // Gas limit for VRF callback (modifiable)

    // Mappings (placed after other state variables)
    mapping(uint256 => RevealRequest) public revealRequests;  // Map requestId to reveal request details
    mapping(address => bool) public approvedNFTContracts;     // Approved NFT contracts
    mapping(bytes32 => RevealStatus) public revealStatus;       // Reveal status per NFT (keyed by hash)

    // ---------- Constructor ----------
    /**
     * @notice Initializes the contract, sets VRF parameters and deploys a timelock.
     * @param _vrfCoordinator Address of the VRF coordinator.
     * @param _strategy Address of the initial reveal strategy contract.
     * @param _subscriptionId Chainlink VRF subscription ID.
     * @param _keyHash Key hash for VRF randomness.
     * @param _requestConfirmations Number of confirmations for VRF requests.
     * @param _callbackGasLimit Gas limit for the VRF callback.
     * @param _numWords Number of random words requested.
     * @param _timelockDelay Delay for timelock operations.
     * @param _owner Address of the owner (proposer/admin for timelock).
     */
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
        // Deploy and initialize timelock controller with owner as proposer/admin.
        address[] memory proposers = new address[](1);
        proposers[0] = _owner;
        address[] memory executors = new address[](1);
        executors[0] = address(0); // Zero address means anyone can execute

        timelock = new TimelockController(
            _timelockDelay,
            proposers,
            executors,
            _owner
        );

        // Set initial reveal strategy and VRF parameters
        revealStrategy = IRevealStrategy(_strategy);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        requestConfirmations = _requestConfirmations;
        callbackGasLimit = _callbackGasLimit;
        numWords = _numWords;
    }

    // ---------- External Functions (Non-View) ----------
    
    /**
     * @notice Schedule a strategy update using the timelock controller.
     * @param newStrategy The address of the new strategy contract.
     * @dev Uses caching of delay (from timelock) to save gas.
     */
    function scheduleStrategyUpdate(address newStrategy) external override onlyOwner {
        if (newStrategy == address(0)) revert CustomErrors.Errors.ZeroAddress();

        // Cache the timelock delay to avoid extra storage reads.
        uint256 delay = timelock.getMinDelay();

        // Encode function call for strategy update.
        bytes memory data = abi.encodeWithSelector(
            this.executeStrategyUpdate.selector,
            newStrategy
        );

        // Schedule the update operation via timelock.
        timelock.schedule(
            address(this),
            0,
            data,
            bytes32(0),
            STRATEGY_UPDATE_OPERATION,
            delay
        );

        emit Events.StrategyUpdateScheduled(newStrategy, block.timestamp + delay);
    }

    /**
     * @notice Execute a scheduled strategy update.
     * @param newStrategy The address of the new strategy contract.
     * @dev Only callable by the timelock; ensures secure update.
     */
    function executeStrategyUpdate(address newStrategy) external override {
        if (msg.sender != address(timelock)) revert CustomErrors.Errors.Unauthorized();

        revealStrategy = IRevealStrategy(newStrategy);
        emit Events.StrategyUpdated(newStrategy);
    }

    /**
     * @notice Cancel a scheduled strategy update.
     * @param newStrategy The strategy address used during scheduling.
     */
    function cancelStrategyUpdate(address newStrategy) external override onlyOwner {
        bytes memory data = abi.encodeWithSelector(
            this.executeStrategyUpdate.selector,
            newStrategy
        );

        // Cancel the scheduled operation by computing its operation ID.
        timelock.cancel(
            bytes32(keccak256(abi.encode(
                address(this),
                0,
                data,
                bytes32(0),
                STRATEGY_UPDATE_OPERATION
            )))
        );

        emit Events.StrategyUpdateCancelled(newStrategy);
    }

    /**
     * @notice Approve or revoke an NFT contract for reveal requests.
     * @param nftContract The address of the NFT contract.
     * @param approved True to approve, false to revoke.
     */
    function setNFTContractApproval(address nftContract, bool approved) external override onlyOwner {
        if (nftContract == address(0)) revert CustomErrors.Errors.ZeroAddress();
        approvedNFTContracts[nftContract] = approved;
        emit Events.NFTContractApprovalChanged(nftContract, approved);
    }

    /**
     * @notice Request randomness for a token reveal.
     * @param nftContract Address of the ERC721 contract.
     * @param tokenId The token ID to reveal.
     * @dev Only works for approved NFT contracts. Uses packed RevealRequest to save gas.
     */
    function reveal(address nftContract, uint256 tokenId) external override {
        bytes32 nftKey = _getNFTKey(nftContract, tokenId);

        // Validate all requirements for a reveal request.
        _validateRevealRequest(nftKey, nftContract, tokenId);

        // Request randomness from Chainlink VRF.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({ nativePayment: true })
                )
            })
        );

        // Store reveal request in a packed struct to save storage gas.
        revealRequests[requestId] = RevealRequest({
            nftContract: nftContract,
            tokenId: uint96(tokenId) // Safe conversion as tokenId is well below 2^96.
        });

        // Mark NFT reveal status as pending.
        revealStatus[nftKey] = RevealStatus.RequestPending;

        emit Events.RandomWordsRequestSent(requestId, nftContract, tokenId);
    }

    /**
     * @notice Update the callback gas limit for VRF requests.
     * @param _callbackGasLimit New gas limit.
     */
    function updateCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
        callbackGasLimit = _callbackGasLimit;
        emit Events.CallbackGasLimitUpdated(_callbackGasLimit);
    }

    /**
     * @notice Update the VRF request confirmations count.
     * @param _requestConfirmations New confirmations count.
     */
    function updateRequestConfirmations(uint16 _requestConfirmations) external onlyOwner {
        requestConfirmations = _requestConfirmations;
        emit Events.RequestConfirmationsUpdated(_requestConfirmations);
    }

    /**
     * @notice Update the timelock delay.
     * @param _timelockDelay New delay value.
     */
    function updateTimelockDelay(uint256 _timelockDelay) external onlyOwner {
        timelock.updateDelay(_timelockDelay);
        emit Events.TimelockDelayUpdated(_timelockDelay);
    }

    // ---------- External View Functions ----------
    
    /**
     * @notice Get the reveal status for a specific NFT.
     * @param nftContract The NFT contract address.
     * @param tokenId The token ID.
     * @return The current RevealStatus.
     */
    function getRevealStatus(address nftContract, uint256 tokenId) external view returns (RevealStatus) {
        return revealStatus[_getNFTKey(nftContract, tokenId)];
    }

    /**
     * @notice Check if a specific NFT has been revealed.
     * @param nftContract The NFT contract address.
     * @param tokenId The token ID.
     * @return True if revealed, false otherwise.
     */
    function isRevealed(address nftContract, uint256 tokenId) external view returns (bool) {
        return revealStatus[_getNFTKey(nftContract, tokenId)] == RevealStatus.Revealed;
    }

    /**
     * @notice Retrieve the current reveal strategy contract address.
     * @return The reveal strategy address.
     */
    function getRevealStrategy() external view returns (address) {
        return address(revealStrategy);
    }

    // ---------- Internal Functions (Non-View) ----------
    
    /**
     * @notice Fulfill randomness request from Chainlink VRF.
     * @dev Called internally by VRFConsumerBaseV2Plus.
     * @param requestId The ID of the randomness request.
     * @param randomWords Array containing the random numbers.
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        RevealRequest memory request = revealRequests[requestId];
        bool success = revealStrategy.reveal(payable(request.nftContract), uint256(request.tokenId), randomWords[0]);
        bytes32 nftKey = _getNFTKey(request.nftContract, uint256(request.tokenId));
        
        if (!success) {
            // If reveal failed, reset status to allow reattempt and clean storage.
            revealStatus[nftKey] = RevealStatus.NotRequested;
            emit Events.RevealFailed(request.nftContract, request.tokenId);
            delete revealRequests[requestId];
            return;
        }
        
        // Mark NFT as revealed and clean up storage.
        revealStatus[nftKey] = RevealStatus.Revealed;
        emit Events.RevealSuccessful(request.nftContract, request.tokenId, randomWords[0]);
        delete revealRequests[requestId];
    }

    // ---------- Internal View/Pure Functions ----------

    /**
     * @notice Validate the requirements for a reveal request.
     * @param nftKey The unique identifier for the NFT.
     * @param nftContract The NFT contract address.
     * @param tokenId The token ID.
     * @dev Performs checks on zero address, ownership, approval, and current reveal status.
     */
    function _validateRevealRequest(
        bytes32 nftKey,
        address nftContract,
        uint256 tokenId
    ) internal view {
        if (nftContract == address(0)) revert CustomErrors.Errors.ZeroAddress();

        // Ensure the caller is the token owner.
        if (IERC721(nftContract).ownerOf(tokenId) != msg.sender)
            revert CustomErrors.Errors.NotTokenOwner(msg.sender, tokenId);

        // Verify that the NFT contract is approved.
        if (!approvedNFTContracts[nftContract])
            revert CustomErrors.Errors.ContractNotApproved(nftContract);

        // Ensure a reveal strategy is set.
        if (address(revealStrategy) == address(0))
            revert CustomErrors.Errors.StrategyNotSet(0);

        // Check that the NFT has not been already requested or revealed.
        if (revealStatus[nftKey] != RevealStatus.NotRequested) {
            if (revealStatus[nftKey] == RevealStatus.Revealed)
                revert CustomErrors.Errors.AlreadyRevealed(tokenId);
            else
                revert CustomErrors.Errors.RevealAlreadyPending(tokenId);
        }
    }

    /**
     * @notice Generate a unique key for an NFT using its contract address and token ID.
     * @param nftContract The NFT contract address.
     * @param tokenId The token ID.
     * @return A bytes32 hash serving as a unique NFT identifier.
     */
    function _getNFTKey(address nftContract, uint256 tokenId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(nftContract, tokenId));
    }
}
