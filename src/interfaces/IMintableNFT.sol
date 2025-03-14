// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IMintableNFT
 * @dev Interface for NFTs that can be minted with metadata
 */
interface IMintableNFT {
    /**
     * @notice Mints a token to a specific address with metadata
     * @param to The address to mint the token to
     * @param tokenId The ID to use for the minted token
     * @param metadata The metadata to associate with the token
     */
    function mint(address to, uint256 tokenId, string memory metadata) external;
}
