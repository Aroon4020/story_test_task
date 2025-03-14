// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title MetadataGenerator
 * @dev Library for generating NFT metadata based on random values
 */
library MetadataGenerator {
    using Strings for uint256;

    /**
     * @notice Generates metadata in JSON format.
     * @param tokenId The ID of the token
     * @param randomness The random value to use for trait selection
     * @return A string containing the complete JSON metadata
     */
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

    /**
     * @notice Generates a value for the Eyes trait
     * @param index The index to use (0-3)
     * @return The trait value
     */
    function getEyesValue(uint256 index) internal pure returns (string memory) {
        if (index == 0) return "Blue";
        if (index == 1) return "Green";
        if (index == 2) return "Brown";
        return "Hazel";
    }

    /**
     * @notice Generates a value for the Hair trait
     * @param index The index to use (0-4)
     * @return The trait value
     */
    function getHairValue(uint256 index) internal pure returns (string memory) {
        if (index == 0) return "Swept Green";
        if (index == 1) return "Blonde";
        if (index == 2) return "Dark Brown";
        if (index == 3) return "Red";
        return "Black";
    }

    /**
     * @notice Generates a value for the Nose trait
     * @param index The index to use (0-2)
     * @return The trait value
     */
    function getNoseValue(uint256 index) internal pure returns (string memory) {
        if (index == 0) return "Small";
        if (index == 1) return "Medium";
        return "Large";
    }

    /**
     * @notice Generates a value for the Mouth trait
     * @param index The index to use (0-3)
     * @return The trait value
     */
    function getMouthValue(uint256 index) internal pure returns (string memory) {
        if (index == 0) return "Pink";
        if (index == 1) return "Red";
        if (index == 2) return "Narrow";
        return "Wide";
    }
}