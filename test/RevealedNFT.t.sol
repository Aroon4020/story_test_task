pragma solidity ^0.8.26;

// ...existing imports...
import {Test} from "forge-std/Test.sol";
import {RevealedNFT} from "../src/RevealedNFT.sol";
import {Errors} from "../src/utils/Errors.sol";  // use alias if needed, e.g., CustomErrors
import {Events} from "../src/utils/Events.sol";

contract RevealedNFTTest is Test {
    RevealedNFT public revealedNFT;
    address public owner;
    address public nonOwner;
    address public approvedStrategy;
    address public notApprovedStrategy;

    function setUp() public {
        // ...initialize test addresses...
        owner = vm.addr(1);
        nonOwner = vm.addr(2);
        approvedStrategy = vm.addr(3);
        notApprovedStrategy = vm.addr(4);
        
        // Deploy RevealedNFT with owner set to 'owner'
        vm.prank(owner);
        revealedNFT = new RevealedNFT(owner);
        
        // Approve a strategy and set it as active
        vm.prank(owner);
        revealedNFT.configureStrategy(approvedStrategy, true, true);
    }
    
    // Test mint: approved strategy can mint and tokenURI returns metadata.
    function testMint_Success() public {
        uint256 tokenId = 0;
        string memory metadata = "revealed metadata";
        
        // Call mint from the approved strategy.
        vm.prank(approvedStrategy);
        revealedNFT.mint(owner, tokenId, metadata);
        
        // Verify that tokenURI returns the expected metadata.
        string memory uri = revealedNFT.tokenURI(tokenId);
        assertEq(uri, metadata, "Token URI should match the provided metadata");
    }
    
    // Test mint: non-approved strategy should revert.
    function testMint_RevertsForNonApproved() public {
        uint256 tokenId = 1;
        string memory metadata = "test metadata";
        
        vm.prank(notApprovedStrategy);
        vm.expectRevert();
        revealedNFT.mint(owner, tokenId, metadata);
    }
    
    // Test that only the owner can configure strategy settings.
    function testConfigureStrategy_OnlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        revealedNFT.configureStrategy(notApprovedStrategy, true, true);
    }
    
    // Test tokenURI reverts for a token that has not been minted.
    function testTokenURI_RevertsForNonexistentToken() public {
        uint256 fakeTokenId = 999;
        vm.expectRevert();
        revealedNFT.tokenURI(fakeTokenId);
    }
}
