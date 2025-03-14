// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IRevealStrategy.sol";
import "../main/SPNFT.sol";
import "../main/RevealedNFT.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SeparateCollectionRevealStrategy is IRevealStrategy {
    using Strings for uint256;
    // Removed invalid overrides
    SPNFT public spNFT;
    RevealedNFT public revealedNFT;

    constructor(address _spNFT, address _revealedNFT) {
        spNFT = SPNFT(_spNFT);
        revealedNFT = RevealedNFT(_revealedNFT);
    }

    /// @notice Reveals a token by burning it in the SPNFT contract and minting a new token in RevealedNFT.
    function reveal(uint256 tokenId, uint256 randomResult) external override returns (bool) {
        // Get token owner before burn.
        address tokenOwner = spNFT.getTokenOwner(tokenId);
        // Burn the original token.
        spNFT.burn(tokenId);
        // Generate metadata for the revealed NFT.
        string memory revealedMetadata = generateMetadata(tokenId, randomResult);
        // Mint the new revealed NFT to the original owner.
        revealedNFT.mint(tokenOwner, tokenId, revealedMetadata);
        return true;
    }

    /// @notice Generates metadata for the revealed NFT.
    function generateMetadata(uint256 tokenId, uint256 randomness) internal pure returns (string memory) {
        // Use different parts of the randomness to determine traits
        string memory eyesValue = getEyesValue(randomness % 4);
        string memory hairValue = getHairValue((randomness / 4) % 5);
        string memory noseValue = getNoseValue((randomness / 20) % 3);
        string memory mouthValue = getMouthValue((randomness / 60) % 4);
        
        return string(
            abi.encodePacked(
                '{"name": "SP', tokenId.toString(), 
                '", "description": "Story Protocol NFT", "attributes": [',
                '{"trait_type": "Eyes", "value": "', eyesValue, '"},',
                '{"trait_type": "Hair", "value": "', hairValue, '"},',
                '{"trait_type": "Nose", "value": "', noseValue, '"},',
                '{"trait_type": "Mouth", "value": "', mouthValue, '"}',
                ']}'
            )
        );
    }

    function getEyesValue(uint256 index) internal pure returns (string memory) {
        if (index == 0) return "Blue";
        if (index == 1) return "Green";
        if (index == 2) return "Brown";
        return "Hazel";
    }

    function getHairValue(uint256 index) internal pure returns (string memory) {
        if (index == 0) return "Swept Green";
        if (index == 1) return "Blonde";
        if (index == 2) return "Dark Brown";
        if (index == 3) return "Red";
        return "Black";
    }

    function getNoseValue(uint256 index) internal pure returns (string memory) {
        if (index == 0) return "Small";
        if (index == 1) return "Medium";
        return "Large";
    }

    function getMouthValue(uint256 index) internal pure returns (string memory) {
        if (index == 0) return "Pink";
        if (index == 1) return "Red";
        if (index == 2) return "Narrow";
        return "Wide";
    }
}
