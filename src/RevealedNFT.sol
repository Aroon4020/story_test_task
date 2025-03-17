// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRevealedNFT.sol";
import "./interfaces/IMintableNFT.sol";
import "./utils/Errors.sol" as CustomErrors;
import "./utils/Events.sol";

contract RevealedNFT is ERC721, Ownable, IRevealedNFT, IMintableNFT {
    // Mapping to store metadata for revealed tokens.
    mapping(uint256 => string) private _tokenMetadata;
    // New strategy management state
    address public revealStrategy;
    mapping(address => bool) public approvedStrategies;

    // Constructor
    constructor(address _owner) ERC721("RevealedNFT", "rSPNFT") Ownable(_owner) {}

    // Modifier restricting functions to approved strategies
    modifier onlyApprovedStrategy() {
        if (!approvedStrategies[msg.sender]) revert CustomErrors.Errors.Unauthorized();
        _;
    }

    /**
     * @notice Configure strategy settings - approve/revoke and optionally set as active
     * @param _strategy The strategy address to configure
     * @param _approved Whether to approve (true) or revoke (false) the strategy
     * @param _setAsActive Whether to also set this strategy as the active one
     */
    function configureStrategy(address _strategy, bool _approved, bool _setAsActive) external onlyOwner {
        if (_strategy == address(0)) revert CustomErrors.Errors.ZeroAddress();

        // Update approval status
        approvedStrategies[_strategy] = _approved;
        emit Events.StrategyApprovalChanged(_strategy, _approved);

        // If requested and approved, set as active strategy
        if (_setAsActive) {
            if (!_approved) revert CustomErrors.Errors.InvalidParameter();
            revealStrategy = _strategy;
            emit Events.RevealStrategySet(_strategy);
        }
    }

    /**
     * @notice Mint a token to a specified address with metadata.
     * Only an approved strategy can call this function.
     */
    function mint(address to, uint256 tokenId, string memory metadata) external override(IRevealedNFT, IMintableNFT) onlyApprovedStrategy {
        _safeMint(to, tokenId);
        _tokenMetadata[tokenId] = metadata;
        emit Events.RevealedNFTMinted(to, tokenId);
    }

    // Public functions
    function tokenURI(uint256 tokenId) public view override(ERC721, IRevealedNFT) returns (string memory) {
        if (!_exists(tokenId)) revert CustomErrors.Errors.TokenNonexistent(tokenId);
        return _tokenMetadata[tokenId];
    }

    // Internal functions
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
