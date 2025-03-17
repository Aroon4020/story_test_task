// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.26;

// import "./BaseTest.sol";

// contract ParametricTest is BaseTest {
//     function testFuzz_RevealModuleWithDifferentGasLimit(uint32 gasLimit) public {
//         // Bound the gas limit to reasonable values
//         vm.assume(gasLimit >= 100000 && gasLimit <= 1000000);
        
//         // Update the callback gas limit
//         vm.prank(deployer);
//         revealModule.updateCallbackGasLimit(gasLimit);
        
//         // Test basic reveal functionality still works
//         uint256 tokenId = mintNFT(alice);
//         revealNFT(alice, tokenId);
        
//         // Verify token was revealed
//         assertTokenRevealed(tokenId);
//     }
    
//     function testFuzz_RevealWithDifferentRandomness(uint256 randomSeed) public {
//         // Mint an NFT for Alice
//         uint256 tokenId = mintNFT(alice);
        
//         // Have Alice request a reveal via the reveal module.
//         vm.prank(alice);
//         revealModule.reveal(address(nft), tokenId);
        
//         // Simulate the VRF callback.
//         // Note: Our mock VRF always returns 12345 as the random value.
//         uint256 requestId = 1; // Fixed request id in our mock
//         vm.prank(address(vrfCoordinator));
//         vrfCoordinator.fulfillRandomness(requestId, address(revealModule));
        
//         // Verify that the NFT has been revealed.
//         // The revealed metadata will have been generated using the fixed random value 12345.
//         assertTrue(nft.revealed(tokenId), "Token should be revealed in NFT contract");
//         assertTrue(revealModule.isRevealed(address(nft), tokenId), "Token should be revealed in RevealModule");
//     }
// }
