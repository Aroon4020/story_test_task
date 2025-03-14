// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../interfaces/IRevealStrategy.sol";
import "../SPNFT.sol";
import "../RevealedNFT.sol";
import "./libraries/MetadataGenerator.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../helpers/Errors.sol";
import "../helpers/Events.sol";

contract SeparateCollectionRevealStrategy is IRevealStrategy, Ownable {
    SPNFT public spNFT;
    RevealedNFT public revealedNFT;
    address public revealModule;
    
    modifier onlyRevealModule() {
        if (msg.sender != revealModule) revert Errors.Unauthorized();
        _;
    }

    constructor(address payable _spNFT, address _revealedNFT, address _owner) Ownable(_owner) {
        spNFT = SPNFT(_spNFT);
        revealedNFT = RevealedNFT(_revealedNFT);
    }
    
    /// @notice Sets the reveal module address - can only be called by owner
    function setRevealModule(address _revealModule) external onlyOwner {
        // Only allow setting once
        if (revealModule != address(0)) revert Errors.RevealModuleAlreadySet();
        if (_revealModule == address(0)) revert Errors.ZeroAddress();
        revealModule = _revealModule;
        emit Events.RevealModuleSetForStrategy(_revealModule);
    }

    /// @notice Reveals a token by burning in source and minting in target collection
    function reveal(uint256 tokenId, uint256 randomResult) external override onlyRevealModule returns (bool) {
        // Get token owner before burn.
        address tokenOwner = spNFT.getTokenOwner(tokenId);
        // Burn the original token.
        spNFT.burn(tokenId);
        // Generate metadata using the library
        string memory revealedMetadata = MetadataGenerator.generateMetadata(tokenId, randomResult);
        // Mint the new revealed NFT to the original owner.
        revealedNFT.mint(tokenOwner, tokenId, revealedMetadata);
        emit Events.TokenBurnedAndMinted(tokenId, tokenOwner, revealedMetadata);
        return true;
    }
}
