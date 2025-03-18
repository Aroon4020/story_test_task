// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseTest} from "./BaseTest.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {RevealModule} from "../src/RevealModule.sol";
import {SPNFT} from "../src/SPNFT.sol";
import {Errors} from "../src/utils/Errors.sol";

contract RevealModuleTest is BaseTest {
    // ================================================================
    // POSITIVE TEST CASES - IN-COLLECTION STRATEGY
    // ================================================================

    function testRevealWithInCollectionStrategy() public {
        // Mint a token using SPNFT
        uint256 tokenId = mintNFT(alice);
        assertFalse(nft.revealed(tokenId), "Token should not be revealed initially");

        // Request reveal using RevealModule flow
        vm.prank(alice);
        revealModule.reveal(address(nft), tokenId);

        // Simulate VRF callback
        uint256 requestId = 1; // Our mock always returns FIXED_REQUEST_ID = 1
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId, address(revealModule));

        // Verify that token is revealed in SPNFT
        assertTrue(nft.revealed(tokenId), "Token should be revealed in SPNFT");
        assertTrue(revealModule.isRevealed(address(nft), tokenId), "RevealModule should mark token as revealed");

        // Token should still be owned by Alice
        assertEq(nft.ownerOf(tokenId), alice, "Token should still be owned by Alice after in-collection reveal");
    }

    function testUpdateCallbackGasLimit() public {
        uint32 newGasLimit = 300000;

        vm.prank(deployer);
        revealModule.updateCallbackGasLimit(newGasLimit);

        // Test basic reveal functionality still works after update
        uint256 tokenId = mintNFT(alice);
        vm.prank(alice);
        revealModule.reveal(address(nft), tokenId);

        // Verify reveal request was sent
        uint256 requestId = 1;
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId, address(revealModule));

        assertTrue(nft.revealed(tokenId), "Token should be revealed after updating gas limit");
    }

    // ================================================================
    // POSITIVE TEST CASES - SEPARATE COLLECTION STRATEGY
    // ================================================================

    function testRevealWithSeparateCollectionStrategy() public {
        // Schedule strategy update using RevealModule's function
        vm.prank(deployer);
        revealModule.scheduleStrategyUpdate(address(separateCollectionStrategy));

        // Fast-forward time past timelock delay
        vm.warp(block.timestamp + timelockDelay + 1);

        // Execute the scheduled update via timelock
        bytes memory callData =
            abi.encodeWithSelector(revealModule.executeStrategyUpdate.selector, address(separateCollectionStrategy));

        vm.prank(deployer);
        revealModule.timelock().execute(
            address(revealModule), 0, callData, bytes32(0), revealModule.STRATEGY_UPDATE_OPERATION()
        );

        // Verify strategy was updated
        assertEq(
            revealModule.getRevealStrategy(),
            address(separateCollectionStrategy),
            "Strategy should be updated to SeparateCollection"
        );

        // Setup appropriately for both NFT contracts
        vm.startPrank(deployer);
        revealedNFT.configureStrategy(address(separateCollectionStrategy), true, true);
        // Add this line to approve SeparateCollectionStrategy for SPNFT as well
        nft.configureStrategy(address(separateCollectionStrategy), true, false); // approve but don't set as active strategy
        vm.stopPrank();

        // 6. Mint a token in SPNFT
        uint256 tokenId = mintNFT(alice);

        // 7. Request reveal
        vm.prank(alice);
        revealModule.reveal(address(nft), tokenId);

        // 8. Simulate VRF callback
        uint256 requestId = 1;
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId, address(revealModule));

        // 9. Verify token burned from SPNFT
        vm.expectRevert();
        nft.ownerOf(tokenId);

        // 10. Verify token minted in RevealedNFT with Alice as owner
        assertEq(revealedNFT.ownerOf(tokenId), alice, "Token should be minted to Alice in RevealedNFT");

        // 11. Verify metadata is set in RevealedNFT
        string memory revealedURI = revealedNFT.tokenURI(tokenId);
        assertTrue(bytes(revealedURI).length > 0, "Token URI should not be empty");
    }

    // New test case: Complete flow with multiple tokens and reveals
    function testCompleteFlow_MultipleTokens() public {
        // 1. Switch to separate collection strategy
        vm.prank(deployer);
        revealModule.scheduleStrategyUpdate(address(separateCollectionStrategy));
        vm.warp(block.timestamp + timelockDelay + 1);

        bytes memory callData =
            abi.encodeWithSelector(revealModule.executeStrategyUpdate.selector, address(separateCollectionStrategy));

        vm.prank(deployer);
        revealModule.timelock().execute(
            address(revealModule), 0, callData, bytes32(0), revealModule.STRATEGY_UPDATE_OPERATION()
        );

        // Configure both NFTs
        vm.startPrank(deployer);
        revealedNFT.configureStrategy(address(separateCollectionStrategy), true, true);
        // Add this line to approve SeparateCollectionStrategy for SPNFT as well
        nft.configureStrategy(address(separateCollectionStrategy), true, false);
        vm.stopPrank();

        // 2. Mint multiple tokens to different addresses
        uint256[] memory aliceTokens = new uint256[](2);
        uint256[] memory bobTokens = new uint256[](2);

        aliceTokens[0] = mintNFT(alice);
        bobTokens[0] = mintNFT(bob);
        aliceTokens[1] = mintNFT(alice);
        bobTokens[1] = mintNFT(bob);

        // 3. Reveal tokens in different order
        uint256 requestId1 = vrfCoordinator.nextRequestId();
        vm.prank(alice);
        revealModule.reveal(address(nft), aliceTokens[0]);

        uint256 requestId2 = vrfCoordinator.nextRequestId();
        vm.prank(bob);
        revealModule.reveal(address(nft), bobTokens[0]);

        // 4. Process VRF callbacks with specific request IDs
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId1, address(revealModule));

        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId2, address(revealModule));

        // 5. Verify first tokens burned and minted correctly
        vm.expectRevert();
        nft.ownerOf(aliceTokens[0]);

        vm.expectRevert();
        nft.ownerOf(bobTokens[0]);

        assertEq(revealedNFT.ownerOf(aliceTokens[0]), alice, "Alice's token should be in RevealedNFT");
        assertEq(revealedNFT.ownerOf(bobTokens[0]), bob, "Bob's token should be in RevealedNFT");

        // 6. Reveal remaining tokens and check results
        vm.prank(alice);
        revealModule.reveal(address(nft), aliceTokens[1]);

        vm.prank(bob);
        revealModule.reveal(address(nft), bobTokens[1]);

        // Instead of specific request IDs, use fulfillAllPending
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillAllPending(address(revealModule));

        // 7. Verify all tokens properly transferred
        assertEq(revealedNFT.ownerOf(aliceTokens[1]), alice, "Alice's second token should be in RevealedNFT");
        assertEq(revealedNFT.ownerOf(bobTokens[1]), bob, "Bob's second token should be in RevealedNFT");
    }

    // New test case: Strategy switching mid-operation
    function testCompleteFlow_StrategySwitching() public {
        // 1. First use the default in-collection strategy
        uint256 tokenId1 = mintNFT(alice);
        uint256 tokenId2 = mintNFT(bob);

        // 2. Reveal token1 with in-collection strategy
        // Get requestId before pranking
        uint256 requestId1 = vrfCoordinator.nextRequestId();

        vm.prank(alice);
        revealModule.reveal(address(nft), tokenId1);

        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId1, address(revealModule));

        // 3. Verify token1 is revealed in-place
        assertTrue(nft.revealed(tokenId1), "Token1 should be revealed in-place");
        assertEq(nft.ownerOf(tokenId1), alice, "Alice should still own token1");

        // 4. Switch to separate collection strategy
        vm.prank(deployer);
        revealModule.scheduleStrategyUpdate(address(separateCollectionStrategy));
        vm.warp(block.timestamp + timelockDelay + 1);

        bytes memory callData =
            abi.encodeWithSelector(revealModule.executeStrategyUpdate.selector, address(separateCollectionStrategy));

        vm.prank(deployer);
        revealModule.timelock().execute(
            address(revealModule), 0, callData, bytes32(0), revealModule.STRATEGY_UPDATE_OPERATION()
        );

        // 5. Configure all affected NFT contracts
        vm.startPrank(deployer);
        revealedNFT.configureStrategy(address(separateCollectionStrategy), true, true);
        nft.configureStrategy(address(separateCollectionStrategy), true, false);
        vm.stopPrank();

        // 6. Reveal token2 with separate collection strategy
        // Get requestId before pranking
        uint256 requestId2 = vrfCoordinator.nextRequestId();

        vm.prank(bob);
        revealModule.reveal(address(nft), tokenId2);

        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId2, address(revealModule));

        // 7. Verify token2 is moved to RevealedNFT
        vm.expectRevert();
        nft.ownerOf(tokenId2);
        assertEq(revealedNFT.ownerOf(tokenId2), bob, "Token2 should be in RevealedNFT");

        // 8. Verify token1 is still in original collection
        assertEq(nft.ownerOf(tokenId1), alice, "Token1 should remain in original collection");
    }

    function testCancelStrategyUpdate() public {
        address newStrategy = address(0xABCD);

        // Schedule using RevealModule's function
        vm.prank(deployer);
        revealModule.scheduleStrategyUpdate(newStrategy);

        // Cancel using RevealModule's function
        vm.prank(deployer);
        revealModule.cancelStrategyUpdate(newStrategy);

        // Fast-forward time past timelock delay
        vm.warp(block.timestamp + timelockDelay + 1);

        // Strategy should remain unchanged
        assertEq(
            revealModule.getRevealStrategy(),
            address(inCollectionStrategy),
            "Strategy should remain unchanged after cancellation"
        );
    }

    function testCancelStrategyUpdate_RevertsForNonOwner() public {
        address newStrategy = address(separateCollectionStrategy);

        // Schedule using RevealModule's function
        vm.prank(deployer);
        revealModule.scheduleStrategyUpdate(newStrategy);

        // Try to cancel as non-owner - should revert
        vm.prank(alice);
        vm.expectRevert();
        revealModule.cancelStrategyUpdate(newStrategy);
    }

    function testSetNFTContractApproval() public {
        address newNFTContract = address(new SPNFT(deployer));

        // Initially not approved
        assertFalse(revealModule.approvedNFTContracts(newNFTContract), "New contract should not be approved initially");

        // Set approval
        vm.prank(deployer);
        revealModule.setNFTContractApproval(newNFTContract, true);

        // Verify approval
        assertTrue(
            revealModule.approvedNFTContracts(newNFTContract),
            "Contract should be approved after setNFTContractApproval"
        );

        // Revoke approval
        vm.prank(deployer);
        revealModule.setNFTContractApproval(newNFTContract, false);

        // Verify revoked
        assertFalse(
            revealModule.approvedNFTContracts(newNFTContract), "Contract should not be approved after revocation"
        );
    }

    // ================================================================
    // NEGATIVE TEST CASES
    // ================================================================

    function testReveal_RevertsForNonOwner() public {
        uint256 tokenId = mintNFT(alice);

        // Bob should not be able to reveal Alice's token
        vm.prank(bob);
        vm.expectRevert();
        revealModule.reveal(address(nft), tokenId);
    }

    function testReveal_RevertsForNonApprovedContract() public {
        // Deploy a new non-approved NFT contract
        SPNFT newNft = new SPNFT(deployer);

        // Alice mints a token on this new contract
        vm.prank(deployer);
        newNft.configureStrategy(address(inCollectionStrategy), true, true);

        vm.deal(alice, 1 ether);
        vm.startPrank(alice);
        uint256 tokenId = newNft.nextTokenId();
        newNft.mint{value: newNft.mintPrice()}();
        vm.stopPrank();

        // Try to reveal via RevealModule - should revert because contract is not approved
        vm.prank(alice);
        vm.expectRevert();
        revealModule.reveal(address(newNft), tokenId);
    }

    function testReveal_RevertsForNonexistentToken() public {
        uint256 nonexistentTokenId = 999; // Token doesn't exist

        vm.prank(alice);
        vm.expectRevert();
        revealModule.reveal(address(nft), nonexistentTokenId);
    }

    function testReveal_RevertsForAlreadyRevealedToken() public {
        uint256 tokenId = mintNFT(alice);

        // First reveal
        vm.prank(alice);
        revealModule.reveal(address(nft), tokenId);

        uint256 requestId = 1;
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId, address(revealModule));

        // Try to reveal again - should revert
        vm.prank(alice);
        vm.expectRevert();
        revealModule.reveal(address(nft), tokenId);
    }

    function testUpdateCallbackGasLimit_RevertsForNonOwner() public {
        uint32 newGasLimit = 300000;

        vm.prank(alice); // Non-owner
        vm.expectRevert();
        revealModule.updateCallbackGasLimit(newGasLimit);
    }

    function testExecuteStrategyUpdate_RevertsForNonTimelock() public {
        address newStrategy = address(separateCollectionStrategy);

        // Try to call executeStrategyUpdate directly - should revert
        vm.prank(deployer);
        vm.expectRevert();
        revealModule.executeStrategyUpdate(newStrategy);
    }

    function testCancelStrategyUpdateRevertsForNonOwner() public {
        address newStrategy = address(separateCollectionStrategy);

        // Schedule update using RevealModule's function
        vm.prank(deployer);
        revealModule.scheduleStrategyUpdate(newStrategy);

        // Try to cancel as non-owner - this should revert
        vm.prank(alice);
        vm.expectRevert();
        revealModule.cancelStrategyUpdate(newStrategy);
    }

    function testSetNFTContractApproval_RevertsForZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert();
        revealModule.setNFTContractApproval(address(0), true);
    }

    function testReveal_RevertsForZeroAddress() public {
        uint256 tokenId = 0;

        vm.prank(alice);
        vm.expectRevert();
        revealModule.reveal(address(0), tokenId);
    }

    function testUpdateRequestConfirmations() public {
        uint16 initialConfirmations = revealModule.requestConfirmations();
        uint16 newConfirmations = 8; // Different value

        vm.prank(deployer);
        revealModule.updateRequestConfirmations(newConfirmations);

        // Verify the update took effect
        assertEq(revealModule.requestConfirmations(), newConfirmations, "Request confirmations should be updated");

        // Verify reveal still works with new confirmation count
        uint256 tokenId = mintNFT(alice);
        vm.prank(alice);
        revealModule.reveal(address(nft), tokenId);

        uint256 requestId = 1;
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId, address(revealModule));

        assertTrue(nft.revealed(tokenId), "Token should be revealed after updating confirmations");
    }

    function testScheduleStrategyUpdate_RevertsForZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
        revealModule.scheduleStrategyUpdate(address(0));
    }
}
