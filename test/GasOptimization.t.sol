// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./BaseTest.sol";

contract GasOptimizationTest is BaseTest {
    function testGasUsage_Reveal() public {
        // Mint and get a valid token ID
        uint256 tokenId = mintNFT(alice);

        // Verify owner before attempting reveal
        console.log("Token owner before reveal:", nft.ownerOf(tokenId));
        assertEq(nft.ownerOf(tokenId), alice, "Alice should own the token");

        // Now test gas usage
        uint256 gasStart = gasleft();
        vm.prank(alice);
        revealModule.reveal(address(nft), tokenId);
        uint256 gasUsed = gasStart - gasleft();

        console.log("Gas used for reveal:", gasUsed);
        assertLt(gasUsed, 300000, "Gas usage should be optimized");
    }

    function testGasUsage_BatchOperations() public {
        // Mint multiple valid NFTs owned by Alice
        uint256[] memory tokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = mintNFT(alice);
            vm.warp(block.timestamp + 1); // Ensure different timestamps for different tokens
        }

        // Compare gas usage for individual operations
        uint256 gasStart = gasleft();
        vm.startPrank(alice);
        for (uint256 i = 0; i < 5; i++) {
            revealModule.reveal(address(nft), tokenIds[i]);
        }
        vm.stopPrank();
        uint256 individualGasUsed = gasStart - gasleft();

        console.log("Gas used for 5 individual reveals:", individualGasUsed);
        console.log("Average gas per reveal:", individualGasUsed / 5);
    }
}
