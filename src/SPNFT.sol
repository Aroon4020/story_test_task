// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISPNFT.sol";
import "./interfaces/IRevealableNFT.sol";
import "./helpers/Errors.sol";
import "./helpers/TransferHelper.sol";
import "./helpers/Events.sol";

contract SPNFT is ERC721, Ownable, ReentrancyGuard, ISPNFT, IRevealableNFT {
    uint256 public override nextTokenId;
    uint256 public override mintPrice = 0.05 ether; 
    string public override basePlaceholderMetadata = '{"name": "Mystery Box", "description": "Unrevealed SP NFT"}';

    // Mapping to store revealed metadata per token
    mapping(uint256 => string) private _revealedMetadata;
    // Tracks whether a token is revealed
    mapping(uint256 => bool) public override revealed;

    // Only the designated RevealModule can update metadata
    address public override revealModule;

    constructor(address _owner) ERC721("SPNFT", "SPNFT") Ownable(_owner) {}

    // Internal function to check if a token exists
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    modifier onlyRevealModule() {
        if (msg.sender != revealModule) revert Errors.Unauthorized();
        _;
    }

    /// @notice Set the reveal module address (callable only by owner)
    function setRevealModule(address _module) external override onlyOwner {
        revealModule = _module;
        emit Events.RevealModuleSet(_module);
    }
    
    /// @notice Update the mint price (callable only by owner)
    function setMintPrice(uint256 _mintPrice) external override onlyOwner {
        mintPrice = _mintPrice;
        emit Events.MintPriceUpdated(mintPrice);
    }

    /// @notice Mint a new SP NFT with placeholder metadata. Requires exact payment.
    function mint() external override payable nonReentrant {
        // Strict requirement for exact payment
        if (msg.value != mintPrice) revert Errors.InvalidPaymentAmount(mintPrice, msg.value);
        
        uint256 tokenId = nextTokenId;
        nextTokenId++;
        _safeMint(msg.sender, tokenId);
        emit Events.TokenMinted(msg.sender, tokenId);
    }
    
    /// @notice Allows owner to withdraw ETH from the contract
    function withdrawETH(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert Errors.ZeroAddress();
        if (amount > address(this).balance) 
            revert Errors.InsufficientFunds(amount, address(this).balance);
        
        TransferHelper.safeTransferETH(to, amount);
        emit Events.ETHWithdrawn(to, amount);
    }

    /// @notice Returns on-chain metadata. If revealed, returns final metadata.
    function tokenURI(uint256 tokenId) public view override(ERC721, ISPNFT) returns (string memory) {
        if (!_exists(tokenId)) revert Errors.TokenNonexistent(tokenId);
        if (revealed[tokenId]) {
            return _revealedMetadata[tokenId];
        } else {
            return basePlaceholderMetadata;
        }
    }

    /// @notice Called by the RevealModule to update a token's metadata upon reveal.
    function setTokenRevealed(uint256 tokenId, string memory metadata) external override(ISPNFT, IRevealableNFT) onlyRevealModule {
        if (!_exists(tokenId)) revert Errors.TokenNonexistent(tokenId);
        _revealedMetadata[tokenId] = metadata;
        revealed[tokenId] = true;
        emit Events.TokenRevealed(tokenId, metadata);
    }

    /// @notice Burn a token (for separate collection reveal). Returns owner before burning.
    function burn(uint256 tokenId) external override(ISPNFT, IRevealableNFT) onlyRevealModule returns (address) {
        address tokenOwner = ownerOf(tokenId);
        _burn(tokenId);
        emit Events.TokenBurned(tokenOwner, tokenId);
        return tokenOwner;
    }

    /// @notice Helper to get token owner (for separate reveal strategy)
    function getTokenOwner(uint256 tokenId) external view override(ISPNFT, IRevealableNFT) returns (address) {
        return ownerOf(tokenId);
    }

    // Receive function to allow contract to receive ETH
    receive() external payable {
        // Allow contract to receive ETH
    }
}
