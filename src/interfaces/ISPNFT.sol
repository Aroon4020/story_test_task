// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ISPNFT {
    function setMintPrice(uint256 _mintPrice) external;
    function configureStrategy(address _strategy, bool _approved, bool _setAsActive) external;
    function mint() external payable;
    function withdrawETH(address to, uint256 amount) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function getRevealStrategy() external view returns (address);
    function setTokenRevealed(uint256 tokenId, string memory metadata) external;
    function burn(uint256 tokenId) external returns (address);
}
