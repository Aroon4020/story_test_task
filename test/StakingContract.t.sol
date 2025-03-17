// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseTest} from "./BaseTest.sol";
import {StakingContract} from "../src/staking/StakingContract.sol";
import {TestERC20} from "./mocks/TestERC20.sol";
import {Events} from "../src/utils/Events.sol";
import {Errors} from "../src/utils/Errors.sol";

contract StakingContractTest is BaseTest {
    // Additional setup
    function setUp() public override {
        super.setUp();
        
        // Mint tokens to users for testing reward additions
        rewardToken.mint(alice, 100 ether);
        rewardToken.mint(bob, 100 ether);
    }
    
    // ================================================================
    // POSITIVE TEST CASES
    // ================================================================
    
    function testSetRevealModule() public {
        address newRevealModule = address(0x1234);
        
        vm.prank(deployer);
        stakingContract.setRevealModule(newRevealModule);
        
        assertEq(address(stakingContract.revealModule()), newRevealModule, "Reveal module should be updated");
    }
    
    function testSetNFTContractApproval() public {
        address newNftContract = address(0x5678);
        
        vm.prank(deployer);
        stakingContract.setNFTContractApproval(newNftContract, true);
        
        assertTrue(stakingContract.approvedNFTContracts(newNftContract), "NFT contract should be approved");
        
        vm.prank(deployer);
        stakingContract.setNFTContractApproval(newNftContract, false);
        
        assertFalse(stakingContract.approvedNFTContracts(newNftContract), "NFT contract should be unapproved");
    }
    
    function testStaking() public {
        // Mint and reveal an NFT
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        
        // Stake the revealed NFT
        vm.startPrank(alice);
        nft.approve(address(stakingContract), tokenId);
        stakingContract.stake(address(nft), tokenId);
        vm.stopPrank();
        
        // Verify ownership transferred to staking contract
        assertEq(nft.ownerOf(tokenId), address(stakingContract), "Staking contract should own the token");
        
        // Verify stake info is recorded
        (address owner,, uint256 stakedAt, bool staked,) = stakingContract.stakes(tokenId);
        assertEq(owner, alice, "Stake owner should be Alice");
        assertTrue(staked, "Token should be marked as staked");
        assertEq(stakedAt, block.timestamp, "Stake timestamp should be current block timestamp");
    }
    
    function testCalculateReward() public {
        // Mint and reveal an NFT
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        
        // Stake the NFT
        stakeNFT(alice, tokenId);
        
        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);
        
        // Calculate reward
        uint256 reward = stakingContract.calculateReward(tokenId);
        assertTrue(reward > 0, "Reward should be greater than zero after 30 days");
        
        // Verify calculation is approximately 5% APY for 30 days
        // Break down the calculation to avoid type conversion issues
        uint256 baseAmount = 1 ether;
        uint256 apyRate = 5;
        uint256 stakingDays = 30;
        uint256 yearDays = 365;
        uint256 percentDivisor = 100;
        
        uint256 expectedReward = (baseAmount * apyRate * stakingDays) / (percentDivisor * yearDays);
        
        // Compare with a small tolerance for rounding differences
        assertApproxEqAbs(reward, expectedReward, 10, "Reward calculation should be close to expected value");
    }
    
    function testUnstake() public {
        // Mint, reveal, and stake an NFT
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);
        
        // Fast forward time to accumulate rewards
        vm.warp(block.timestamp + 30 days);
        
        // Track initial balances
        uint256 initialRewardBalance = rewardToken.balanceOf(alice);
        
        // Unstake the NFT
        vm.prank(alice);
        stakingContract.unstake(tokenId);
        
        // Verify token returned to owner
        assertEq(nft.ownerOf(tokenId), alice, "NFT should be returned to Alice");
        
        // Verify rewards were transferred
        assertTrue(rewardToken.balanceOf(alice) > initialRewardBalance, "Alice should receive rewards");
        
        // Verify stake is cleared
        (,, , bool staked,) = stakingContract.stakes(tokenId);
        assertFalse(staked, "Token should be marked as unstaked");
    }
    
    function testClaimReward() public {
        // Mint, reveal, and stake an NFT
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);
        
        // Fast forward time to accumulate rewards
        vm.warp(block.timestamp + 30 days);
        
        // Calculate expected rewards
        uint256 expectedReward = stakingContract.calculateReward(tokenId);
        uint256 initialRewardBalance = rewardToken.balanceOf(alice);
        
        // Claim rewards without unstaking
        vm.prank(alice);
        stakingContract.claimReward(tokenId);
        
        // Verify rewards were transferred
        assertEq(rewardToken.balanceOf(alice), initialRewardBalance + expectedReward, "Alice should receive exact rewards");
        
        // Verify token is still staked
        assertEq(nft.ownerOf(tokenId), address(stakingContract), "NFT should still be staked");
        
        // Verify staking timestamp was reset
        (,, uint256 stakedAt,,) = stakingContract.stakes(tokenId);
        assertEq(stakedAt, block.timestamp, "Staking timestamp should be reset");
        
        // Verify calculating rewards now returns zero
        assertEq(stakingContract.calculateReward(tokenId), 0, "No rewards immediately after claiming");
    }
    
    function testAddReward() public {
        uint256 amount = 10 ether;
        uint256 initialContractBalance = rewardToken.balanceOf(address(stakingContract));
        
        // Approve and add rewards
        vm.startPrank(alice);
        rewardToken.approve(address(stakingContract), amount);
        stakingContract.addReward(amount);
        vm.stopPrank();
        
        // Verify rewards were transferred
        assertEq(
            rewardToken.balanceOf(address(stakingContract)), 
            initialContractBalance + amount, 
            "Contract should receive reward tokens"
        );
    }
    
    function testWithdrawReward() public {
        uint256 amount = 5 ether;
        uint256 initialContractBalance = rewardToken.balanceOf(address(stakingContract));
        uint256 initialDeployerBalance = rewardToken.balanceOf(deployer);
        
        // Withdraw rewards
        vm.prank(deployer);
        stakingContract.withdrawReward(deployer, amount);
        
        // Verify rewards were transferred
        assertEq(
            rewardToken.balanceOf(address(stakingContract)), 
            initialContractBalance - amount, 
            "Contract balance should decrease"
        );
        assertEq(
            rewardToken.balanceOf(deployer), 
            initialDeployerBalance + amount, 
            "Deployer should receive reward tokens"
        );
    }
    
    // ================================================================
    // NEGATIVE TEST CASES
    // ================================================================
    
    function testSetRevealModule_RevertForNonOwner() public {
        vm.prank(alice); // non-owner
        vm.expectRevert();
        stakingContract.setRevealModule(address(0x1234));
    }
    
    function testSetRevealModule_RevertForZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert();
        stakingContract.setRevealModule(address(0));
    }
    
    function testSetNFTContractApproval_RevertForNonOwner() public {
        vm.prank(alice); // non-owner
        vm.expectRevert();
        stakingContract.setNFTContractApproval(address(0x1234), true);
    }
    
    function testSetNFTContractApproval_RevertForZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert();
        stakingContract.setNFTContractApproval(address(0), true);
    }
    
    function testStake_RevertForNonApprovedContract() public {
        address unapprovedContract = address(0x9876);
        uint256 tokenId = 1;
        
        vm.prank(alice);
        vm.expectRevert();
        stakingContract.stake(unapprovedContract, tokenId);
    }
    
    function testStake_RevertForUnrevealedToken() public {
        // Mint but don't reveal
        uint256 tokenId = mintNFT(alice);
        
        vm.prank(alice);
        vm.expectRevert();
        stakingContract.stake(address(nft), tokenId);
    }
    
    function testStake_RevertForNonOwner() public {
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        
        vm.prank(bob); // not the token owner
        vm.expectRevert();
        stakingContract.stake(address(nft), tokenId);
    }
    
    function testUnstake_RevertForNonStakedToken() public {
        uint256 nonStakedTokenId = 999;
        
        vm.prank(alice);
        vm.expectRevert();
        stakingContract.unstake(nonStakedTokenId);
    }
    
    function testUnstake_RevertForNonOwner() public {
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);
        
        vm.prank(bob); // not the staker
        vm.expectRevert();
        stakingContract.unstake(tokenId);
    }
    
    function testClaimReward_RevertForNonStakedToken() public {
        uint256 nonStakedTokenId = 999;
        
        vm.prank(alice);
        vm.expectRevert();
        stakingContract.claimReward(nonStakedTokenId);
    }
    
    function testClaimReward_RevertForNonOwner() public {
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);
        
        vm.prank(bob); // not the staker
        vm.expectRevert();
        stakingContract.claimReward(tokenId);
    }
    
    function testWithdrawReward_RevertForNonOwner() public {
        vm.prank(alice); // non-owner
        vm.expectRevert();
        stakingContract.withdrawReward(alice, 1 ether);
    }
    
    function testWithdrawReward_RevertForZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert();
        stakingContract.withdrawReward(address(0), 1 ether);
    }
}
