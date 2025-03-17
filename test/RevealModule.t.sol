// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseTest} from "./BaseTest.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {RevealModule} from "../src/RevealModule.sol";
import {SPNFT} from "../src/SPNFT.sol";

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
    
    function testUpdateVRFParameters() public {
        bytes32 newKeyHash = bytes32(uint256(2));
        uint64 newSubscriptionId = 2;
        uint16 newRequestConfirmations = 5;
        uint32 newCallbackGasLimit = 250000;
        uint32 newNumWords = 1;
        
        vm.prank(deployer);
        revealModule.updateVRFParameters(
            newKeyHash,
            newSubscriptionId,
            newRequestConfirmations,
            newCallbackGasLimit,
            newNumWords
        );
        
        // Test basic reveal functionality still works after update
        uint256 tokenId = mintNFT(alice);
        vm.prank(alice);
        revealModule.reveal(address(nft), tokenId);
        
        // Verify reveal request was sent (our mock ignores parameter changes)
        uint256 requestId = 1;
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId, address(revealModule));
        
        assertTrue(nft.revealed(tokenId), "Token should be revealed after updating VRF parameters");
    }

    // ================================================================
    // POSITIVE TEST CASES - SEPARATE COLLECTION STRATEGY
    // ================================================================
    
    function testRevealWithSeparateCollectionStrategy() public {
        // First, update the RevealModule's strategy to SeparateCollectionStrategy via timelock.
        TimelockController timelock = revealModule.timelock();
        
        // Schedule strategy update
        vm.prank(deployer);
        revealModule.scheduleStrategyUpdate(address(separateCollectionStrategy));
        
        // Retrieve the function call data for timelock
        bytes memory data = abi.encodeWithSelector(
            revealModule.executeStrategyUpdate.selector,
            address(separateCollectionStrategy)
        );
        
        // Fast-forward time past timelock delay
        vm.warp(block.timestamp + timelockDelay + 1);
        
        // Execute the scheduled update via timelock
        vm.prank(deployer);
        timelock.execute(
            address(revealModule),
            0,
            data,
            bytes32(0),
            revealModule.STRATEGY_UPDATE_OPERATION()
        );
        
        // Verify strategy was updated
        assertEq(revealModule.getRevealStrategy(), address(separateCollectionStrategy), "Strategy should be updated to SeparateCollection");
        
        // Setup appropriately
        vm.startPrank(deployer);
        // Approve RevealedNFT to use the separate collection strategy
        revealedNFT.configureStrategy(address(separateCollectionStrategy), true, true);
        vm.stopPrank();
        
        // Mint a token from SPNFT
        uint256 tokenId = mintNFT(alice);
        
        // Request reveal
        vm.prank(alice);
        revealModule.reveal(address(nft), tokenId);
        
        uint256 requestId = 1;
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId, address(revealModule));
        
        // Verify that the token no longer exists in SPNFT (was burned)
        vm.expectRevert();
        nft.ownerOf(tokenId);
        
        // Verify that the token exists in RevealedNFT with Alice as owner
        assertEq(revealedNFT.ownerOf(tokenId), alice, "Token should be minted to Alice in RevealedNFT");
        
        // Verify token URI is no longer the placeholder
        string memory revealedURI = revealedNFT.tokenURI(tokenId);
        assertTrue(bytes(revealedURI).length > 0, "Token URI should not be empty");
    }
    
    function testCancelStrategyUpdate() public {
        address newStrategy = address(0xABCD);
        
        // Schedule strategy update
        vm.prank(deployer);
        revealModule.scheduleStrategyUpdate(newStrategy);
        
        // Cancel the scheduled update
        vm.prank(deployer);
        revealModule.cancelStrategyUpdate(newStrategy);
        
        // Fast-forward time past timelock delay
        vm.warp(block.timestamp + timelockDelay + 1);
        
        // Strategy should remain unchanged
        assertEq(revealModule.getRevealStrategy(), address(inCollectionStrategy), "Strategy should remain unchanged after cancellation");
    }
    
    function testSetNFTContractApproval() public {
        address newNFTContract = address(new SPNFT(deployer));
        
        // Initially not approved
        assertFalse(revealModule.approvedNFTContracts(newNFTContract), "New contract should not be approved initially");
        
        // Set approval
        vm.prank(deployer);
        revealModule.setNFTContractApproval(newNFTContract, true);
        
        // Verify approval
        assertTrue(revealModule.approvedNFTContracts(newNFTContract), "Contract should be approved after setNFTContractApproval");
        
        // Revoke approval
        vm.prank(deployer);
        revealModule.setNFTContractApproval(newNFTContract, false);
        
        // Verify revoked
        assertFalse(revealModule.approvedNFTContracts(newNFTContract), "Contract should not be approved after revocation");
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
    
    function testUpdateVRFParameters_RevertsForNonOwner() public {
        bytes32 newKeyHash = bytes32(uint256(2));
        
        vm.prank(alice); // Non-owner
        vm.expectRevert();
        revealModule.updateVRFParameters(newKeyHash, 2, 5, 250000, 2);
    }
    
    function testExecuteStrategyUpdate_RevertsForNonTimelock() public {
        address newStrategy = address(separateCollectionStrategy);
        
        // Try to call executeStrategyUpdate directly - should revert
        vm.prank(deployer);
        vm.expectRevert();
        revealModule.executeStrategyUpdate(newStrategy);
    }
    
    function testCancelStrategyUpdate_RevertsForNonOwner() public {
        address newStrategy = address(separateCollectionStrategy);
        
        // Schedule update
        vm.prank(deployer);
        revealModule.scheduleStrategyUpdate(newStrategy);
        
        // Try to cancel as non-owner
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
}
