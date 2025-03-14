// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IRevealableNFT
 * @dev Interface for NFTs that can have their metadata revealed
 */
interface IRevealableNFT {
    /**
     * @notice Updates the token's metadata after revealing
     * @param tokenId The ID of the token to reveal
     * @param metadata The revealed metadata to set
     */
    function setTokenRevealed(uint256 tokenId, string memory metadata) external;
    
    /**
     * @notice Gets the current owner of a token
     * @param tokenId The ID of the token to query
     * @return The address of the token owner
     */
    function getTokenOwner(uint256 tokenId) external view returns (address);
    
    /**
     * @notice Burns a token, used in separate collection reveal pattern
     * @param tokenId The ID of the token to burn
     * @return The address of the token owner before burning
     */
    function burn(uint256 tokenId) external returns (address);
}
