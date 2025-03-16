// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRevealedNFT.sol";
import "./interfaces/IMintableNFT.sol";
import "./utils/Errors.sol" as CustomErrors;  // Use alias to avoid conflict
import "./utils/Events.sol";

contract RevealedNFT is ERC721, Ownable, IRevealedNFT, IMintableNFT {
    // Mapping to store metadata for revealed tokens.
    mapping(uint256 => string) private _tokenMetadata;
    
    // Remove invalid override since IRevealedNFT doesn't declare revealModule
    address public revealModule;

    // Constructor
    constructor(address _owner) ERC721("RevealedNFT", "rSPNFT") Ownable(_owner) {}

    // Modifiers
    modifier onlyRevealModule() {
        if (msg.sender != revealModule) revert CustomErrors.Errors.Unauthorized();
        _;
    }

    // External functions
    function setRevealModule(address _module) external onlyOwner {
        revealModule = _module;
        emit Events.RevealModuleSet(_module);
    }

    function mint(address to, uint256 tokenId, string memory metadata) external override(IRevealedNFT, IMintableNFT) onlyRevealModule {
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
