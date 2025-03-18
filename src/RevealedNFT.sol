// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ---------- Imports ----------
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRevealedNFT.sol";
import "./utils/Errors.sol" as CustomErrors;
import "./utils/Events.sol";

// ---------- Contract Declaration ----------
/**
 * @title RevealedNFT
 * @notice Story Protocol NFT implementation with on-chain metadata and reveal mechanism.
 * @dev Extends ERC721 and supports strategy-based metadata reveal.
 */
contract RevealedNFT is ERC721, Ownable, IRevealedNFT {
    // ---------- State Variables ----------

    // Active reveal strategy contract address
    address public revealStrategy;

    // ---------- Mappings ----------
    // Mapping to store approval status for strategies that are allowed to call restricted functions.
    mapping(address => bool) public approvedStrategies;

    // Mapping to store metadata for revealed tokens.
    mapping(uint256 => string) private _tokenMetadata;

    // ---------- Constructor ----------
    /**
     * @notice Initializes the RevealedNFT contract.
     * @param _owner The address of the contract owner.
     */
    constructor(address _owner) ERC721("RevealedNFT", "rSPNFT") Ownable(_owner) {}

    // ---------- Modifiers ----------
    /**
     * @notice Restricts function execution to approved strategy contracts.
     */
    modifier onlyApprovedStrategy() {
        if (!approvedStrategies[msg.sender]) revert CustomErrors.Errors.Unauthorized();
        _;
    }

    // ---------- External Functions ----------
    /**
     * @notice Configure strategy settings - approve/revoke a strategy and optionally set it as active.
     * @param _strategy The strategy address to configure.
     * @param _approved Whether to approve (true) or revoke (false) the strategy.
     * @param _setAsActive Whether to also set this strategy as the active one.
     */
    function configureStrategy(address _strategy, bool _approved, bool _setAsActive) external onlyOwner {
        if (_strategy == address(0)) revert CustomErrors.Errors.ZeroAddress();

        // Update strategy approval status.
        approvedStrategies[_strategy] = _approved;
        emit Events.StrategyApprovalChanged(_strategy, _approved);

        // If requested and approved, set as active strategy.
        if (_setAsActive) {
            if (!_approved) revert CustomErrors.Errors.InvalidParameter();
            revealStrategy = _strategy;
            emit Events.RevealStrategySet(_strategy);
        }
    }

    /**
     * @notice Mint a new NFT with its revealed metadata.
     * @param to Recipient address.
     * @param tokenId Token ID to mint.
     * @param metadata The metadata for the token.
     * @dev Only an approved strategy can call this function.
     */
    function mint(address to, uint256 tokenId, string memory metadata)
        external
        override(IRevealedNFT)
        onlyApprovedStrategy
    {
        _safeMint(to, tokenId);
        _tokenMetadata[tokenId] = metadata;
        emit Events.RevealedNFTMinted(to, tokenId);
    }

    // ---------- Public Functions ----------
    /**
     * @notice Returns the metadata URI for a given token.
     * @param tokenId The token ID.
     * @return The token's metadata URI as a string.
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, IRevealedNFT) returns (string memory) {
        if (!_exists(tokenId)) revert CustomErrors.Errors.TokenNonexistent(tokenId);
        return _tokenMetadata[tokenId];
    }

    // ---------- Internal Functions ----------
    /**
     * @notice Checks if a token exists.
     * @param tokenId The token ID to check.
     * @return True if the token exists, false otherwise.
     * @dev Uses ERC721's internal _ownerOf method.
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
