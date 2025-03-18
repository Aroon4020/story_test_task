// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ---------- External Imports ----------
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// ---------- Internal Imports ----------
import "../interfaces/IRevealStrategy.sol";
import "../interfaces/ISPNFT.sol";
import "../interfaces/IRevealedNFT.sol";
import "./libraries/MetadataGenerator.sol";
import "../utils/Events.sol";
import "../utils/Errors.sol";

/**
 * @title SeparateCollectionRevealStrategy
 * @notice Implements a reveal strategy for separate NFT collections by burning tokens in the original collection and minting them with revealed metadata.
 * @dev Uses on-chain metadata generation via MetadataGenerator. Only the designated reveal module is permitted to call the reveal function.
 */
contract SeparateCollectionRevealStrategy is IRevealStrategy, Ownable {
    // ---------- State Variables ----------
    
    // Revealed NFT contract instance used to mint revealed tokens.
    IRevealedNFT public immutable revealedNFT;
    
    // Address of the module allowed to trigger the reveal process.
    address public revealModule;
    
    // ---------- Modifiers ----------
    /**
     * @notice Restricts function execution to the designated reveal module.
     */
    modifier onlyRevealModule() {
        if (msg.sender != revealModule) revert Errors.Unauthorized();
        _;
    }
    
    // ---------- Constructor ----------
    /**
     * @notice Initializes the SeparateCollectionRevealStrategy contract.
     * @param _revealedNFT The address of the revealed NFT contract.
     * @param _owner The owner of this strategy contract.
     */
    constructor(address _revealedNFT, address _owner) Ownable(_owner) {
        revealedNFT = IRevealedNFT(_revealedNFT);
    }
    
    // ---------- External Functions ----------
    /**
     * @notice Set the reveal module address. Can only be set once.
     * @param _revealModule The address of the reveal module.
     * @dev Reverts if a reveal module is already set or if the provided address is zero.
     */
    function setRevealModule(address _revealModule) external onlyOwner {
        if (revealModule != address(0)) revert Errors.RevealModuleAlreadySet();
        if (_revealModule == address(0)) revert Errors.ZeroAddress();
        revealModule = _revealModule;
        emit Events.RevealModuleSetForStrategy(_revealModule);
    }
    
    /**
     * @notice Reveal a token by burning it in the original collection and minting it with generated metadata.
     * @param nftContract The address of the NFT contract (must implement ISPNFT and IERC721).
     * @param tokenId The token ID to reveal.
     * @param randomResult A random number used to generate revealed metadata.
     * @return True if the reveal process is successful.
     * @dev Only callable by the designated reveal module.
     */
    function reveal(
        address payable nftContract,
        uint256 tokenId,
        uint256 randomResult
    )
        external
        override
        onlyRevealModule
        returns (bool)
    {
        // Retrieve the token owner using the ERC721 interface.
        address tokenOwner = IERC721(nftContract).ownerOf(tokenId);
        
        // Burn the token from the original collection using the ISPNFT interface.
        ISPNFT(nftContract).burn(tokenId);
        
        // Generate the revealed metadata using the provided random result.
        string memory revealedMetadata = MetadataGenerator.generateMetadata(tokenId, randomResult);
        
        // Mint the new revealed token to the original owner via the revealedNFT contract.
        revealedNFT.mint(tokenOwner, tokenId, revealedMetadata);
        
        // Emit event logging the burn and mint operation.
        emit Events.TokenBurnedAndMinted(tokenId, tokenOwner, revealedMetadata);
        return true;
    }
}
