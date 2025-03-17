// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./BaseTest.sol";

contract MintRevealStakeTest is BaseTest {
    function setUp() public override {
        super.setUp();
        // Additional setup specific to this test
    }
    
    function testE2EFlow_MintRevealStake() public {
        // 1. Alice mints a token
        uint256 tokenId = mintNFT(alice);
        
        // Print the accurate addresses for debugging
        console.log("Alice address:", alice);
        console.log("Token owner:", nft.ownerOf(tokenId));
        
        assertEq(nft.ownerOf(tokenId), alice, "Alice should own the token");
        assertFalse(nft.revealed(tokenId), "Token should not be revealed yet");
        
        // 2. Alice reveals the token
        revealNFT(alice, tokenId);
        assertTrue(nft.revealed(tokenId), "Token should be revealed");
        
        // 3. Alice stakes the token
        stakeNFT(alice, tokenId);
        assertEq(nft.ownerOf(tokenId), address(stakingContract), "Staking contract should own the token");
        
        // 4. Alice unstakes after some time
        vm.warp(block.timestamp + 30 days); // Fast-forward 30 days
        
        uint256 rewardBefore = rewardToken.balanceOf(alice);
        vm.prank(alice);
        stakingContract.unstake(tokenId);
        
        assertEq(nft.ownerOf(tokenId), alice, "Alice should own the token again");
        assertTrue(rewardToken.balanceOf(alice) > rewardBefore, "Alice should receive rewards");
    }
}
