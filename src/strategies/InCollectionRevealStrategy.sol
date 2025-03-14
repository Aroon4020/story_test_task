// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../interfaces/IRevealStrategy.sol";
import "../SPNFT.sol";
import "./libraries/MetadataGenerator.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../helpers/Errors.sol";
import "../helpers/Events.sol";

contract InCollectionRevealStrategy is IRevealStrategy, Ownable {
    SPNFT public spNFT;
    address public revealModule;
    
    modifier onlyRevealModule() {
        if (msg.sender != revealModule) revert Errors.Unauthorized();
        _;
    }

    constructor(address payable _spNFT, address _owner) Ownable(_owner) {
        spNFT = SPNFT(_spNFT);
    }
    
    /// @notice Sets the reveal module address - can only be called by owner
    function setRevealModule(address _revealModule) external onlyOwner {
        // Only allow setting once
        if (revealModule != address(0)) revert Errors.RevealModuleAlreadySet();
        if (_revealModule == address(0)) revert Errors.ZeroAddress();
        revealModule = _revealModule;
        emit Events.RevealModuleSetForStrategy(_revealModule);
    }

    /// @notice Reveals a token by generating metadata on-chain and updating the SPNFT contract.
    function reveal(uint256 tokenId, uint256 randomResult) external override onlyRevealModule returns (bool) {
        string memory revealedMetadata = MetadataGenerator.generateMetadata(tokenId, randomResult);
        spNFT.setTokenRevealed(tokenId, revealedMetadata);
        emit Events.TokenRevealExecuted(tokenId, randomResult);
        return true;
    }
}