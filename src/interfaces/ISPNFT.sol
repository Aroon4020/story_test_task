// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ISPNFT {
    function nextTokenId() external view returns (uint256);
    function mintPrice() external view returns (uint256);
    function basePlaceholderMetadata() external view returns (string memory);
    function revealed(uint256 tokenId) external view returns (bool);
    function revealModule() external view returns (address);
    
    function setRevealModule(address _module) external;
    function setMintPrice(uint256 _mintPrice) external; // New function
    function mint() external payable;
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function setTokenRevealed(uint256 tokenId, string memory metadata) external;
    function burn(uint256 tokenId) external returns (address);
    function getTokenOwner(uint256 tokenId) external view returns (address);
}
