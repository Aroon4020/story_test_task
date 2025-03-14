// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISPNFT.sol";
import "../strategies/interfaces/IRevealableNFT.sol";

contract SPNFT is ERC721, Ownable, ReentrancyGuard, ISPNFT, IRevealableNFT {
    uint256 public override nextTokenId;
    uint256 public override mintPrice = 0.05 ether; // Example mint price
    string public override basePlaceholderMetadata = '{"name": "Mystery Box", "description": "Unrevealed SP NFT"}';

    // Mapping to store revealed metadata per token
    mapping(uint256 => string) private _revealedMetadata;
    // Tracks whether a token is revealed
    mapping(uint256 => bool) public override revealed;

    // Only the designated RevealModule can update metadata
    address public override revealModule;

    constructor() ERC721("SPNFT", "SPNFT") Ownable(msg.sender) {}

    // Internal function to check if a token exists
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    modifier onlyRevealModule() {
        require(msg.sender == revealModule, "Not authorized");
        _;
    }

    /// @notice Set the reveal module address (callable only by owner)
    function setRevealModule(address _module) external override onlyOwner {
        revealModule = _module;
    }

    /// @notice Mint a new SP NFT with placeholder metadata. Refunds excess Ether.
    function mint() external override payable nonReentrant {
        require(msg.value >= mintPrice, "Insufficient funds");
        uint256 tokenId = nextTokenId;
        nextTokenId++;
        _safeMint(msg.sender, tokenId);
        // Refund excess if any
        if (msg.value > mintPrice) {
            payable(msg.sender).transfer(msg.value - mintPrice);
        }
    }

    /// @notice Returns on-chain metadata. If revealed, returns final metadata.
    function tokenURI(uint256 tokenId) public view override(ERC721, ISPNFT) returns (string memory) {
        require(_exists(tokenId), "Nonexistent token");
        if (revealed[tokenId]) {
            return _revealedMetadata[tokenId];
        } else {
            return basePlaceholderMetadata;
        }
    }

    /// @notice Called by the RevealModule to update a token's metadata upon reveal.
    function setTokenRevealed(uint256 tokenId, string memory metadata) external override(ISPNFT, IRevealableNFT) onlyRevealModule {
        require(_exists(tokenId), "Nonexistent token");
        _revealedMetadata[tokenId] = metadata;
        revealed[tokenId] = true;
    }

    /// @notice Burn a token (for separate collection reveal). Returns owner before burning.
    function burn(uint256 tokenId) external override(ISPNFT, IRevealableNFT) onlyRevealModule returns (address) {
        address tokenOwner = ownerOf(tokenId);
        _burn(tokenId);
        return tokenOwner;
    }

    /// @notice Helper to get token owner (for separate reveal strategy)
    function getTokenOwner(uint256 tokenId) external view override(ISPNFT, IRevealableNFT) returns (address) {
        return ownerOf(tokenId);
    }
}
