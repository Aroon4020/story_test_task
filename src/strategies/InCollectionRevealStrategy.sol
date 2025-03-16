// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../interfaces/IRevealStrategy.sol";
import "../SPNFT.sol";
import "./libraries/MetadataGenerator.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../utils/Events.sol";

contract InCollectionRevealStrategy is IRevealStrategy, Ownable {
    SPNFT public spNFT;
    address public revealModule;
    
    modifier onlyRevealModule() {
        if (msg.sender != revealModule) revert CustomErrors.Errors.Unauthorized();
        _;
    }

    constructor(address _owner) Ownable(_owner) {}
    
    function setRevealModule(address _revealModule) external onlyOwner {
        if (revealModule != address(0)) revert CustomErrors.Errors.RevealModuleAlreadySet();
        if (_revealModule == address(0)) revert CustomErrors.Errors.ZeroAddress();
        revealModule = _revealModule;
        emit Events.RevealModuleSetForStrategy(_revealModule);
    }

    function reveal(address payable nftContract, uint256 tokenId, uint256 randomResult) external override onlyRevealModule returns (bool) {
        string memory revealedMetadata = MetadataGenerator.generateMetadata(tokenId, randomResult);
        SPNFT(nftContract).setTokenRevealed(tokenId, revealedMetadata);
        emit Events.TokenRevealExecuted(tokenId, randomResult);
        return true;
    }
}