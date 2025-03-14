// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IRevealStrategy.sol";
import "../main/SPNFT.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract InCollectionRevealStrategy is IRevealStrategy {
    using Strings for uint256;
    // Removed invalid override
    SPNFT public spNFT;

    constructor(address _spNFT) {
        spNFT = SPNFT(_spNFT);
    }

    /// @notice Reveals a token by generating metadata on-chain and updating the SPNFT contract.
    function reveal(uint256 tokenId, uint256 randomResult) external override returns (bool) {
        // Generate dummy metadata based on tokenId and randomResult.
        string memory revealedMetadata = generateMetadata(tokenId, randomResult);
        spNFT.setTokenRevealed(tokenId, revealedMetadata);
        return true;
    }

    /// @notice Generates metadata in JSON format.
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
