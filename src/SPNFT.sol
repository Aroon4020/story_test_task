// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol"; 
import "@openzeppelin/contracts/utils/Address.sol"; 
import "./interfaces/ISPNFT.sol";
import "./interfaces/IRevealableNFT.sol";
import "./interfaces/IRevealStrategy.sol"; // Add this import for strategy interface
import "./utils/Errors.sol" as CustomErrors;
import "./utils/Events.sol";

/**
 * @title SPNFT
 * @notice Story Protocol NFT implementation with on-chain metadata and reveal mechanism
 * @dev Extends ERC721 with revealing capabilities for metadata
 */
contract SPNFT is ERC721, Ownable, ReentrancyGuard, ISPNFT, IRevealableNFT, ERC721Holder {
    using Address for address payable;
    
    //--------------------------------------------------------------------------
    // STATE VARIABLES
    //--------------------------------------------------------------------------
    
    /// @notice Counter for the next token to be minted
    uint256 public override nextTokenId;
    
    /// @notice Current price to mint an NFT
    uint256 public override mintPrice = 0.05 ether; 
    
    /// @notice Default metadata for unrevealed NFTs
    string public override basePlaceholderMetadata = '{"name": "Mystery Box", "description": "Unrevealed SP NFT"}';

    /// @dev Mapping to store revealed metadata per token
    mapping(uint256 => string) private _revealedMetadata;
    
    /// @notice Tracks whether a token has been revealed
    mapping(uint256 => bool) public override revealed;

    /// @notice Current active reveal strategy
    address public revealStrategy;
    
    /// @notice Approved strategies that can interact with this contract
    mapping(address => bool) public approvedStrategies;
    
    //--------------------------------------------------------------------------
    // CONSTRUCTOR
    //--------------------------------------------------------------------------

    constructor(address _owner) ERC721("SPNFT", "SPNFT") Ownable(_owner) {}

    //--------------------------------------------------------------------------
    // RECEIVE FUNCTION
    //--------------------------------------------------------------------------

    receive() external payable {
        // Allow contract to receive ETH
    }
    
    //--------------------------------------------------------------------------
    // MODIFIERS
    //--------------------------------------------------------------------------

    /**
     * @notice Restricts function to be called only by approved strategies
     */
    modifier onlyApprovedStrategy() {
        if (!approvedStrategies[msg.sender]) revert CustomErrors.Errors.Unauthorized();
        _;
    }

    //--------------------------------------------------------------------------
    // EXTERNAL FUNCTIONS
    //--------------------------------------------------------------------------

    /**
     * @notice Configure strategy settings - approve/revoke and optionally set as active
     * @param _strategy The strategy address to configure
     * @param _approved Whether to approve (true) or revoke (false) the strategy
     * @param _setAsActive Whether to also set this strategy as the active one
     */
    function configureStrategy(address _strategy, bool _approved, bool _setAsActive) external onlyOwner {
        if (_strategy == address(0)) revert CustomErrors.Errors.ZeroAddress();
        
        // Update approval status
        approvedStrategies[_strategy] = _approved;
        emit Events.StrategyApprovalChanged(_strategy, _approved);
        
        // If requested and approved, set as active strategy
        if (_setAsActive) {
            if (!_approved) revert CustomErrors.Errors.InvalidParameter();
            revealStrategy = _strategy;
            emit Events.RevealStrategySet(_strategy);
        }
    }
    
    /**
     * @notice Update the price required to mint a new NFT
     * @param _mintPrice New price in wei
     */
    function setMintPrice(uint256 _mintPrice) external override onlyOwner {
        mintPrice = _mintPrice;
        emit Events.MintPriceUpdated(mintPrice);
    }
    
    /**
     * @notice Withdraw ETH from the contract to a specified address
     * @param to Recipient address
     * @param amount Amount of ETH to withdraw
     */
    function withdrawETH(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert CustomErrors.Errors.ZeroAddress();
        if (amount > address(this).balance) 
            revert CustomErrors.Errors.InsufficientFunds(amount, address(this).balance);
        
        payable(to).sendValue(amount);
        emit Events.ETHWithdrawn(to, amount);
    }

    /**
     * @notice Mint a new NFT with unrevealed metadata
     * @dev Requires exact payment of mintPrice
     */
    function mint() external override payable nonReentrant {
        if (msg.value != mintPrice) revert CustomErrors.Errors.InvalidPaymentAmount(mintPrice, msg.value);
        
        uint256 tokenId = nextTokenId;
        nextTokenId++;
        _safeMint(msg.sender, tokenId);
        emit Events.TokenMinted(msg.sender, tokenId);
    }
    
    /**
     * @notice Update a token's metadata when revealed
     * @param tokenId ID of the token to reveal
     * @param metadata New metadata for the token
     */
    function setTokenRevealed(uint256 tokenId, string memory metadata) external override(ISPNFT, IRevealableNFT) onlyApprovedStrategy {
        if (!_exists(tokenId)) revert CustomErrors.Errors.TokenNonexistent(tokenId);
        _revealedMetadata[tokenId] = metadata;
        revealed[tokenId] = true;
        emit Events.TokenRevealed(tokenId, metadata);
    }

    /**
     * @notice Burn a token (only approved strategies can call)
     * @param tokenId ID of the token to burn
     * @return Owner of the token before burning
     */
    function burn(uint256 tokenId) external override(ISPNFT, IRevealableNFT) onlyApprovedStrategy returns (address) {
        address tokenOwner = ownerOf(tokenId);
        _burn(tokenId);
        emit Events.TokenBurned(tokenOwner, tokenId);
        return tokenOwner;
    }
    
    /**
     * @notice Reveal a token using the current strategy
     * @param tokenId ID of the token to reveal
     * @param randomResult Random value to use for the reveal
     */
    function revealToken(uint256 tokenId, uint256 randomResult) external onlyOwner {
        if (revealStrategy == address(0)) revert CustomErrors.Errors.StrategyNotSet(0);
        if (!_exists(tokenId)) revert CustomErrors.Errors.TokenNonexistent(tokenId);
        if (revealed[tokenId]) revert CustomErrors.Errors.AlreadyRevealed(tokenId);
        
        // Call the strategy to handle the reveal
        bool success = IRevealStrategy(revealStrategy).reveal(payable(address(this)), tokenId, randomResult);
        if (!success) revert CustomErrors.Errors.RevealFailed(tokenId);
    }
    
    /**
     * @notice Get the owner of a specific token
     * @param tokenId ID of the token
     * @return Address of the token's owner
     */
    function getTokenOwner(uint256 tokenId) external view override(ISPNFT, IRevealableNFT) returns (address) {
        return ownerOf(tokenId);
    }

    //--------------------------------------------------------------------------
    // PUBLIC FUNCTIONS
    //--------------------------------------------------------------------------
    
    /**
     * @notice Returns the URI for a token's metadata
     * @param tokenId ID of the token
     * @return Metadata URI as a string
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ISPNFT) returns (string memory) {
        if (!_exists(tokenId)) revert CustomErrors.Errors.TokenNonexistent(tokenId);
        if (revealed[tokenId]) {
            return _revealedMetadata[tokenId];
        } else {
            return basePlaceholderMetadata;
        }
    }

    //--------------------------------------------------------------------------
    // INTERNAL FUNCTIONS
    //--------------------------------------------------------------------------
    
    /**
     * @notice Check if a token exists
     * @param tokenId ID of the token to check
     * @return Whether the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
