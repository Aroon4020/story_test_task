// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRevealedNFT.sol";
import "./interfaces/IMintableNFT.sol";
import "./helpers/Errors.sol";
import "./helpers/Events.sol";

contract RevealedNFT is ERC721, Ownable, IRevealedNFT, IMintableNFT {
    // Mapping to store metadata for revealed tokens.
    mapping(uint256 => string) private _tokenMetadata;
    
    // Remove invalid override since IRevealedNFT doesn't declare revealModule
    address public revealModule;

    // Internal function to check if a token exists
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    modifier onlyRevealModule() {
        if (msg.sender != revealModule) revert Errors.Unauthorized();
        _;
    }

    // Fixed constructor to pass parameters to base contracts
    constructor(address _owner) ERC721("RevealedNFT", "rSPNFT") Ownable(_owner) {}

    /// @notice Sets the reveal module address (callable only by owner)
    function setRevealModule(address _module) external onlyOwner {
        revealModule = _module;
        emit Events.RevealModuleSet(_module);
    }

    /// @notice Mints a new revealed NFT with metadata.
    function mint(address to, uint256 tokenId, string memory metadata) external override(IRevealedNFT, IMintableNFT) onlyRevealModule {
        _safeMint(to, tokenId);
        _tokenMetadata[tokenId] = metadata;
        emit Events.RevealedNFTMinted(to, tokenId);
    }

    /// @notice Returns the metadata for a token.
    function tokenURI(uint256 tokenId) public view override(ERC721, IRevealedNFT) returns (string memory) {
        if (!_exists(tokenId)) revert Errors.TokenNonexistent(tokenId);
        return _tokenMetadata[tokenId];
    }
}
