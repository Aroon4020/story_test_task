// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRevealedNFT {
    function revealModule() external view returns (address);
    
    function setRevealModule(address _module) external;
    function mint(address to, uint256 tokenId, string memory metadata) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
