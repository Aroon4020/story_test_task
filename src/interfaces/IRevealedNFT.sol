// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRevealedNFT {
    function mint(address to, uint256 tokenId, string memory metadata) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
