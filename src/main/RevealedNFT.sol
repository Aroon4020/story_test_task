// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRevealedNFT.sol";
import "../strategies/interfaces/IMintableNFT.sol";

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
        require(msg.sender == revealModule, "Not authorized");
        _;
    }

    // Fixed constructor to pass parameters to base contracts
    constructor() ERC721("RevealedNFT", "rSPNFT") Ownable(msg.sender) {}

    /// @notice Sets the reveal module address (callable only by owner)
    function setRevealModule(address _module) external onlyOwner {
        revealModule = _module;
    }

    /// @notice Mints a new revealed NFT with metadata.
    function mint(address to, uint256 tokenId, string memory metadata) external override(IRevealedNFT, IMintableNFT) onlyRevealModule {
        _safeMint(to, tokenId);
        _tokenMetadata[tokenId] = metadata;
    }

    /// @notice Returns the metadata for a token.
    function tokenURI(uint256 tokenId) public view override(ERC721, IRevealedNFT) returns (string memory) {
        require(_exists(tokenId), "Nonexistent token");
        return _tokenMetadata[tokenId];
    }
}
