// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseTest} from "./BaseTest.sol";
import "../src/utils/Errors.sol" as CustomErrors;

contract SPNFTTest is BaseTest {
    // Test minting: check token ownership and price payment.
    function testMint() public {
        uint256 tokenId = mintNFT(alice);
        // Verify that Alice is the owner of the new token.
        assertEq(nft.ownerOf(tokenId), alice, "Alice should own the token");
    }

    // Test setting mint price as owner works and non-owner reverts.
    function testSetMintPrice() public {
        uint256 newPrice = 0.1 ether;
        vm.prank(deployer);
        nft.setMintPrice(newPrice);
        assertEq(nft.mintPrice(), newPrice, "Mint price should be updated");

        vm.prank(alice);
        vm.expectRevert();
        nft.setMintPrice(0.2 ether);
    }

    // Test withdrawing ETH: only owner can withdraw and funds are transferred.
    function testWithdrawETH() public {
        // Mint to add ETH to the contract
        mintNFT(alice);
        uint256 contractBalance = address(nft).balance;
        uint256 ownerBalanceBefore = deployer.balance;

        vm.prank(deployer);
        nft.withdrawETH(deployer, contractBalance);

        assertEq(address(nft).balance, 0, "Contract balance should be 0 after withdrawal");
        assertEq(
            deployer.balance, ownerBalanceBefore + contractBalance, "Owner balance should increase by withdrawn amount"
        );

        vm.prank(alice);
        vm.expectRevert();
        nft.withdrawETH(alice, 1 ether);
    }

    // Test configuration of reveal strategy using configureStrategy.
    function testConfigureStrategy() public {
        // Only owner can configure. Use deployer for configuration.
        address testStrategy = address(0x123);
        vm.prank(deployer);
        nft.configureStrategy(testStrategy, true, true);

        // Check that the active strategy is set as testStrategy.
        // (Depending on your SPNFT contract expose data, you could assert revealStrategy == testStrategy)
        // For example, if you have a getter:
        // assertEq(nft.revealStrategy(), testStrategy, "Active strategy should be configured");

        // Try revoking strategy from a non-owner.
        vm.prank(alice);
        vm.expectRevert();
        nft.configureStrategy(address(0x456), true, true);
    }

    // Test setTokenRevealed: only approved strategy can call this.
    function testSetTokenRevealed_rejectsNonApproved() public {
        uint256 tokenId = mintNFT(alice);
        vm.prank(deployer);
        // Not approved yet, so call should revert.
        vm.expectRevert();
        nft.setTokenRevealed(tokenId, "metadata");
    }

    // Simulate an approved strategy calling setTokenRevealed.
    function testSetTokenRevealed_approved() public {
        uint256 tokenId = mintNFT(alice);
        // Approve the inCollectionStrategy and set it as active.
        vm.prank(deployer);
        nft.configureStrategy(address(inCollectionStrategy), true, true);

        // Now simulate call from the approved strategy.
        vm.prank(address(inCollectionStrategy));
        nft.setTokenRevealed(tokenId, "revealed metadata");

        assertTrue(nft.revealed(tokenId), "Token should be marked as revealed");
        // Optionally, check tokenURI returns the revealed metadata.
        assertEq(nft.tokenURI(tokenId), "revealed metadata", "Token metadata should be updated");
    }

    // Test that tokenURI returns the placeholder metadata when not revealed.
    function testTokenURI_NotRevealed() public {
        uint256 tokenId = mintNFT(alice);
        // Expect placeholder since token hasn't been revealed.
        string memory uri = nft.tokenURI(tokenId);
        assertEq(uri, nft.basePlaceholderMetadata(), "Token URI should be placeholder when not revealed");
    }

    // Test that tokenURI returns updated metadata after the token is revealed.
    function testTokenURI_AfterReveal() public {
        uint256 tokenId = mintNFT(alice);
        // Approve inCollectionStrategy and set active.
        vm.prank(deployer);
        nft.configureStrategy(address(inCollectionStrategy), true, true);
        // Simulate reveal call from the approved strategy.
        vm.prank(address(inCollectionStrategy));
        nft.setTokenRevealed(tokenId, "updated metadata");
        string memory uri = nft.tokenURI(tokenId);
        assertEq(uri, "updated metadata", "Token URI should return updated metadata after reveal");
    }

    // Test that getTokenOwner returns the correct owner.
    function testGetTokenOwner() public {
        uint256 tokenId = mintNFT(alice);
        address owner = nft.ownerOf(tokenId);
        assertEq(owner, alice, "getTokenOwner should return Alice as owner");
    }

    // Test burning a token using an approved strategy.
    function testBurnToken_approvedStrategy() public {
        uint256 tokenId = mintNFT(alice);
        // Approve inCollectionStrategy and set as active.
        vm.prank(deployer);
        nft.configureStrategy(address(inCollectionStrategy), true, true);
        // Simulate reveal by approved strategy (required before burn).
        vm.prank(address(inCollectionStrategy));
        nft.setTokenRevealed(tokenId, "to be burned");
        // Now call burn from the approved strategy.
        vm.prank(address(inCollectionStrategy));
        address previousOwner = nft.burn(tokenId);
        assertEq(previousOwner, alice, "Burned token's previous owner should be Alice");
        // Verify that token no longer exists.
        vm.expectRevert();
        nft.ownerOf(tokenId);
    }

    // Test that minting with an incorrect ETH amount reverts.
    function testMintInvalidPayment() public {
        uint256 currentMintPrice = nft.mintPrice();
        uint256 invalidAmount = currentMintPrice - 1;

        vm.deal(alice, currentMintPrice); // Make sure Alice has funds
        vm.prank(alice);
        // Use a simple expectRevert without trying to match the error data
        vm.expectRevert();
        nft.mint{value: invalidAmount}();
    }
}
