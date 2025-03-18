// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ---------- Imports ----------
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/ISPNFT.sol";
import "./interfaces/IRevealStrategy.sol";
import "./utils/Errors.sol" as CustomErrors;
import "./utils/Events.sol";

// ---------- Contract Declaration ----------
/**
 * @title SPNFT
 * @notice Story Protocol NFT implementation with on-chain metadata and reveal mechanism.
 * @dev Extends ERC721 with metadata reveal capabilities.
 */
contract SPNFT is ERC721, Ownable, ReentrancyGuard, ISPNFT, ERC721Holder {
    using Address for address payable;

    // ---------- State Variables ----------
    // Regular variables
    uint256 public nextTokenId;                   // Counter for the next token to be minted
    uint256 public mintPrice = 0.05 ether;          // Price to mint an NFT
    string public basePlaceholderMetadata = '{"name": "Mystery Box", "description": "Unrevealed SP NFT"}'; // Default metadata for unrevealed NFTs
    address public revealStrategy;                  // Active reveal strategy contract address

    // Mappings (declared after regular variables)
    mapping(uint256 => string) private _revealedMetadata; // Revealed metadata per tokenId
    mapping(uint256 => bool) public revealed;             // Tracks whether a token has been revealed
    mapping(address => bool) public approvedStrategies;   // Approved strategy contracts

    // ---------- Modifiers ----------
    /**
     * @notice Restricts function execution to approved strategy contracts.
     */
    modifier onlyApprovedStrategy() {
        if (!approvedStrategies[msg.sender]) revert CustomErrors.Errors.Unauthorized();
        _;
    }

    // ---------- Constructor ----------
    /**
     * @notice Initializes the SPNFT contract by setting the token name, symbol, and owner.
     * @param _owner The owner address.
     */
    constructor(address _owner)
        ERC721("SPNFT", "SPNFT")
        Ownable(_owner)
    {}

    // ---------- Receive Function ----------
    /**
     * @notice Allows the contract to receive ETH.
     */
    receive() external payable {
        // Intentionally left blank to accept ETH transfers.
    }

    // ---------- External Non-View Functions ----------
    /**
     * @notice Configure a strategy by approving/revoking it and optionally set it as active.
     * @param _strategy The strategy address.
     * @param _approved True to approve, false to revoke.
     * @param _setAsActive True to set this strategy as active.
     */
    function configureStrategy(
        address _strategy,
        bool _approved,
        bool _setAsActive
    ) external override onlyOwner {
        if (_strategy == address(0)) revert CustomErrors.Errors.ZeroAddress();

        // Update strategy approval status.
        approvedStrategies[_strategy] = _approved;
        emit Events.StrategyApprovalChanged(_strategy, _approved);

        // If requested, set the strategy as active.
        if (_setAsActive) {
            if (!_approved) revert CustomErrors.Errors.InvalidParameter();
            revealStrategy = _strategy;
            emit Events.RevealStrategySet(_strategy);
        }
    }

    /**
     * @notice Update the mint price for NFT creation.
     * @param _mintPrice The new mint price in wei.
     */
    function setMintPrice(uint256 _mintPrice) external override onlyOwner {
        mintPrice = _mintPrice;
        emit Events.MintPriceUpdated(mintPrice);
    }

    /**
     * @notice Withdraw ETH from the contract.
     * @param to The recipient address.
     * @param amount The amount of ETH to withdraw.
     */
    function withdrawETH(address to, uint256 amount) external override onlyOwner {
        if (to == address(0)) revert CustomErrors.Errors.ZeroAddress();
        if (amount > address(this).balance)
            revert CustomErrors.Errors.InsufficientFunds(amount, address(this).balance);

        payable(to).sendValue(amount);
        emit Events.ETHWithdrawn(to, amount);
    }

    /**
     * @notice Mint a new NFT with unrevealed metadata.
     * @dev Requires exact payment equal to mintPrice.
     */
    function mint() external override payable nonReentrant {
        if (msg.value != mintPrice)
            revert CustomErrors.Errors.InvalidPaymentAmount(mintPrice, msg.value);

        uint256 tokenId = nextTokenId;
        // Use unchecked arithmetic for gas optimization (safe as tokenId increments are predictable).
        unchecked { nextTokenId = tokenId + 1; }

        _safeMint(msg.sender, tokenId);
        emit Events.TokenMinted(msg.sender, tokenId);
    }

    /**
     * @notice Update a token's metadata when it is revealed.
     * @param tokenId The token ID to reveal.
     * @param metadata The new revealed metadata.
     */
    function setTokenRevealed(uint256 tokenId, string memory metadata)
        external
        override
        onlyApprovedStrategy
    {
        if (!_exists(tokenId)) revert CustomErrors.Errors.TokenNonexistent(tokenId);

        _revealedMetadata[tokenId] = metadata;
        revealed[tokenId] = true;
        emit Events.TokenRevealed(tokenId, metadata);
    }

    /**
     * @notice Burn an NFT.
     * @param tokenId The token ID to burn.
     * @return The address of the token owner prior to burning.
     */
    function burn(uint256 tokenId)
        external
        override
        onlyApprovedStrategy
        returns (address)
    {
        address tokenOwner = ownerOf(tokenId);
        _burn(tokenId);
        emit Events.TokenBurned(tokenOwner, tokenId);
        return tokenOwner;
    }

    // ---------- External View Functions ----------
    /**
     * @notice Retrieve the current active reveal strategy.
     * @return The reveal strategy contract address.
     */
    function getRevealStrategy() external view returns (address) {
        return revealStrategy;
    }

    // ---------- Public Functions ----------
    /**
     * @notice Returns the metadata URI for a given token.
     * @param tokenId The token ID.
     * @return The token's metadata URI.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ISPNFT)
        returns (string memory)
    {
        if (!_exists(tokenId)) revert CustomErrors.Errors.TokenNonexistent(tokenId);
        if (revealed[tokenId]) {
            return _revealedMetadata[tokenId];
        } else {
            return basePlaceholderMetadata;
        }
    }

    // ---------- Internal Functions ----------
    /**
     * @notice Checks if a token exists.
     * @param tokenId The token ID to check.
     * @return True if the token exists, false otherwise.
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        // Leverage ERC721's internal owner lookup (_ownerOf is provided by OpenZeppelin's ERC721).
        return _ownerOf(tokenId) != address(0);
    }
}
