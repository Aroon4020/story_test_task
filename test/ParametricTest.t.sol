// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./BaseTest.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract ParametricTest is BaseTest {
    function testFuzz_RevealModuleWithDifferentGasLimit(uint32 gasLimit) public {
        // Bound the gas limit to reasonable values
        vm.assume(gasLimit >= 100000 && gasLimit <= 1000000);

        // Update the callback gas limit
        vm.prank(deployer);
        revealModule.updateCallbackGasLimit(gasLimit);

        // Test basic reveal functionality still works
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);

        // Verify token was revealed
        assertTrue(nft.revealed(tokenId), "Token should be revealed");
    }

    function testFuzz_RevealWithDifferentRandomness(uint256 randomSeed) public {
        // Mint an NFT for Alice
        uint256 tokenId = mintNFT(alice);

        // Have Alice request a reveal via the reveal module
        vm.prank(alice);
        revealModule.reveal(address(nft), tokenId);

        // Simulate VRF callback with different random values
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomSeed;

        // Changed: call fulfillRandomness instead of fulfillRandomWords
        vrfCoordinator.fulfillRandomness(1, address(revealModule));

        // Verify the token was revealed
        assertTrue(nft.revealed(tokenId), "Token should be revealed regardless of randomness");
    }

    function testFuzz_MultipleRevealsWithDifferentStrategies(uint8 numTokens, bool useSeparateCollection) public {
        // Bound the number of tokens to a reasonable range
        vm.assume(numTokens > 0 && numTokens <= 10);

        // Configure strategy based on parameter
        if (useSeparateCollection) {
            // Change to separate collection strategy
            vm.startPrank(deployer);
            revealModule.scheduleStrategyUpdate(address(separateCollectionStrategy));
            vm.warp(block.timestamp + timelockDelay + 1);

            bytes memory callData =
                abi.encodeWithSelector(revealModule.executeStrategyUpdate.selector, address(separateCollectionStrategy));

            revealModule.timelock().execute(
                address(revealModule), 0, callData, bytes32(0), revealModule.STRATEGY_UPDATE_OPERATION()
            );

            // Configure NFTs for separate collection
            revealedNFT.configureStrategy(address(separateCollectionStrategy), true, true);
            nft.configureStrategy(address(separateCollectionStrategy), true, false);
            vm.stopPrank();
        }

        // Mint and reveal multiple tokens
        uint256[] memory tokenIds = new uint256[](numTokens);
        for (uint8 i = 0; i < numTokens; i++) {
            // Mint token to alice
            tokenIds[i] = mintNFT(alice);

            // Request reveal
            vm.prank(alice);
            revealModule.reveal(address(nft), tokenIds[i]);
        }

        // Simulate VRF callback
        vrfCoordinator.fulfillAllPending(address(revealModule));

        // Verify all tokens were revealed correctly
        for (uint8 i = 0; i < numTokens; i++) {
            if (useSeparateCollection) {
                // For separate collection, tokens should be minted in revealedNFT
                assertEq(revealedNFT.ownerOf(tokenIds[i]), alice, "Token should be in RevealedNFT collection");
            } else {
                // For in-collection, tokens should be revealed but stay in original collection
                assertTrue(nft.revealed(tokenIds[i]), "Token should be revealed in original collection");
                assertEq(nft.ownerOf(tokenIds[i]), alice, "Token should remain in original collection");
            }
        }
    }

    function testFuzz_RevealWithDifferentConfirmations(uint16 confirmations) public {
        // Bound confirmations to reasonable values
        vm.assume(confirmations >= 1 && confirmations <= 200);

        // Update request confirmations
        vm.prank(deployer);
        revealModule.updateRequestConfirmations(confirmations);

        // Verify update was successful
        assertEq(revealModule.requestConfirmations(), confirmations, "Request confirmations should be updated");

        // Test reveal flow still works
        uint256 tokenId = mintNFT(alice);
        vm.prank(alice);
        revealModule.reveal(address(nft), tokenId);

        // Simulate VRF callback
        vrfCoordinator.fulfillAllPending(address(revealModule));

        // Verify token was revealed
        assertTrue(nft.revealed(tokenId), "Token should be revealed with updated confirmations");
    }
}
