// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ---------- External Imports ----------
import "@openzeppelin/contracts/access/Ownable.sol";

// ---------- Internal Imports ----------
import "../interfaces/IRevealStrategy.sol";
import "../interfaces/ISPNFT.sol";
import "./libraries/MetadataGenerator.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";

/**
 * @title InCollectionRevealStrategy
 * @notice Implements a reveal strategy where tokens are revealed within the same collection.
 * @dev Generates metadata on-chain and calls setTokenRevealed on the NFT contract.
 */
contract InCollectionRevealStrategy is IRevealStrategy, Ownable {
    // ---------- State Variables ----------

    // The SPNFT contract instance used for token management.
    ISPNFT public spNFT;

    // ---------- Other State Variables ----------

    // Address authorized to trigger the reveal process.
    address public revealModule;

    // ---------- Modifiers ----------
    /**
     * @notice Restricts function calls to the designated reveal module.
     */
    modifier onlyRevealModule() {
        if (msg.sender != revealModule) revert Errors.Unauthorized();
        _;
    }

    // ---------- Constructor ----------
    /**
     * @notice Initializes the InCollectionRevealStrategy contract.
     * @param _owner The address of the contract owner.
     */
    constructor(address _owner) Ownable(_owner) {}

    // ---------- External Functions ----------

    /**
     * @notice Sets the reveal module address. Can only be set once.
     * @param _revealModule The address to set as the reveal module.
     * @dev Reverts if a reveal module is already set or if _revealModule is the zero address.
     */
    function setRevealModule(address _revealModule) external onlyOwner {
        if (revealModule != address(0)) revert Errors.RevealModuleAlreadySet();
        if (_revealModule == address(0)) revert Errors.ZeroAddress();
        revealModule = _revealModule;
        emit Events.RevealModuleSetForStrategy(_revealModule);
    }

    /**
     * @notice Reveals a token by generating metadata and updating its revealed status.
     * @param nftContract The address of the NFT contract.
     * @param tokenId The token ID to reveal.
     * @param randomResult A random number used to generate metadata.
     * @return True if the reveal process is successful.
     * @dev Only callable by the designated reveal module.
     */
    function reveal(address payable nftContract, uint256 tokenId, uint256 randomResult)
        external
        override
        onlyRevealModule
        returns (bool)
    {
        // Generate the new metadata using the provided random number.
        string memory revealedMetadata = MetadataGenerator.generateMetadata(tokenId, randomResult);

        // Call setTokenRevealed on the NFT contract to update metadata.
        ISPNFT(nftContract).setTokenRevealed(tokenId, revealedMetadata);

        // Emit an event logging that the token was revealed.
        emit Events.TokenRevealExecuted(tokenId, randomResult);
        return true;
    }
}
