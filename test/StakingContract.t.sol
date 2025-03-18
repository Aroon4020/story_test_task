// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseTest} from "./BaseTest.sol";
import {StakingContract} from "../src/staking/StakingContract.sol";
import {TestERC20} from "./mocks/TestERC20.sol";
import {Events} from "../src/utils/Events.sol";
import {Errors} from "../src/utils/Errors.sol";
import {SPNFT} from "../src/SPNFT.sol"; // Added SPNFT import

contract StakingContractTest is BaseTest {
    // Additional setup
    function setUp() public override {
        super.setUp();

        // Mint tokens to users for testing reward additions
        rewardToken.mint(alice, 100 ether);
        rewardToken.mint(bob, 100 ether);
        rewardToken.mint(deployer, 1000 ether); // Added - ensure deployer has plenty of tokens
    }

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

        // Verify the NFT ownership transferred to staking contract
        assertEq(nft.ownerOf(tokenId), address(stakingContract), "Staking contract should own the token");

        // Verify stake info is recorded via getStakeInfo
        (address owner, uint96 stakedAt) = stakingContract.getStakeInfo(address(nft), tokenId);
        assertEq(owner, alice, "Stake owner should be Alice");
        // stakedAt should be set close to block.timestamp (tolerance set to 1 second)
        assertApproxEqAbs(uint256(stakedAt), block.timestamp, 1, "Stake timestamp should be current block timestamp");
    }

    function testCalculateReward() public {
        // Mint and reveal an NFT, then stake it
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);

        // Get staking time
        (, uint96 stakedAt) = stakingContract.getStakeInfo(address(nft), tokenId);

        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        // Calculate reward passing the stored staking timestamp
        uint256 reward = stakingContract.calculateReward(stakedAt);
        assertTrue(reward > 0, "Reward should be greater than zero after 30 days");

        // Expected reward calculation (using base = 1eX where X = rewardToken.decimals())
        uint256 baseAmount = 10 ** rewardToken.decimals();
        uint256 expectedReward = (baseAmount * 5 * 30 days) / (100 * 365 days);
        // Allow small rounding differences
        assertApproxEqAbs(reward, expectedReward, 1e5, "Reward calculation should be close to expected value");
    }

    function testUnstake() public {
        // Mint, reveal, and stake an NFT
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);

        // Ensure the staking contract has sufficient rewards by directly minting to it
        rewardToken.mint(address(stakingContract), 100 ether);

        // Fast forward time to accumulate significant rewards
        vm.warp(block.timestamp + 100 days);

        // Calculate expected reward
        (, uint96 stakedAt) = stakingContract.getStakeInfo(address(nft), tokenId);
        uint256 expectedReward = stakingContract.calculateReward(stakedAt);

        // Verify calculated reward is non-zero (sanity check)
        assertTrue(expectedReward > 0, "Expected reward should be greater than zero");

        // Track initial balance
        uint256 aliceInitialBalance = rewardToken.balanceOf(alice);

        // Unstake the NFT
        vm.prank(alice);
        stakingContract.unstakeAndClaimReward(address(nft), tokenId);

        // Verify token returned to owner
        assertEq(nft.ownerOf(tokenId), alice, "NFT should be returned to Alice");

        // Verify rewards were transferred
        uint256 aliceFinalBalance = rewardToken.balanceOf(alice);
        assertTrue(aliceFinalBalance > aliceInitialBalance, "Alice should receive rewards");

        // Verify stake info cleared
        (address owner, uint96 stakedAt2) = stakingContract.getStakeInfo(address(nft), tokenId);
        assertEq(owner, address(0), "Stake owner should be cleared");
        assertEq(stakedAt2, 0, "Staking timestamp should be cleared");
    }

    function testUnstakeAndClaimReward() public {
        // Mint, reveal, and stake an NFT
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);

        // Fast forward time to accumulate reward
        vm.warp(block.timestamp + 30 days);

        uint256 aliceRewardBefore = rewardToken.balanceOf(alice);

        // Unstake and claim reward
        vm.prank(alice);
        stakingContract.unstakeAndClaimReward(address(nft), tokenId);

        // Verify NFT returned to owner
        assertEq(nft.ownerOf(tokenId), alice, "NFT should be returned to Alice");
        // Verify rewards received increased Alice's balance
        uint256 aliceRewardAfter = rewardToken.balanceOf(alice);
        assertTrue(aliceRewardAfter > aliceRewardBefore, "Rewards should be transferred to Alice");

        // Verify stake info cleared
        (address owner, uint96 stakedAt) = stakingContract.getStakeInfo(address(nft), tokenId);
        assertEq(owner, address(0), "Stake owner should be cleared after unstakeAndClaimReward");
        assertEq(stakedAt, 0, "Staking timestamp should be cleared after unstakeAndClaimReward");
    }

    function testClaimReward() public {
        // Mint, reveal, and stake an NFT
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);

        // Fast forward time to accumulate rewards
        vm.warp(block.timestamp + 30 days);

        // Get stakedAt from stake info using getStakeInfo (returns (address, uint96))
        (, uint96 stakedAtBefore) = stakingContract.getStakeInfo(address(nft), tokenId);
        uint256 expectedReward = stakingContract.calculateReward(stakedAtBefore);
        uint256 initialRewardBalance = rewardToken.balanceOf(alice);

        // Claim rewards without unstaking
        vm.prank(alice);
        stakingContract.claimReward(address(nft), tokenId);

        // Verify rewards were transferred
        assertEq(
            rewardToken.balanceOf(alice), initialRewardBalance + expectedReward, "Alice should receive exact rewards"
        );

        // Verify NFT is still staked
        assertEq(nft.ownerOf(tokenId), address(stakingContract), "NFT should still be staked");

        // Verify staking timestamp was reset using getStakeInfo
        (, uint96 stakedAtAfter) = stakingContract.getStakeInfo(address(nft), tokenId);
        assertApproxEqAbs(uint256(stakedAtAfter), block.timestamp, 1, "Staking timestamp should be reset");

        // Since rewards accumulate based on time, immediately after claiming reward should be zero:
        assertEq(stakingContract.calculateReward(stakedAtAfter), 0, "No rewards immediately after claiming");
    }

    function testAddReward() public {
        uint256 amount = 10 ether;
        uint256 initialContractBalance = rewardToken.balanceOf(address(stakingContract));

        // Approve and add rewards
        vm.startPrank(alice);
        rewardToken.approve(address(stakingContract), amount);
        stakingContract.depositReward(amount);
        vm.stopPrank();

        // Verify rewards were transferred
        assertEq(
            rewardToken.balanceOf(address(stakingContract)),
            initialContractBalance + amount,
            "Contract should receive reward tokens"
        );
    }

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
        // Now passing the NFT address along
        stakingContract.unstake(address(nft), nonStakedTokenId);
    }

    function testUnstake_RevertForNonOwner() public {
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);

        vm.prank(bob); // not the staker
        vm.expectRevert();
        stakingContract.unstake(address(nft), tokenId);
    }

    function testClaimReward_RevertForNonStakedToken() public {
        uint256 nonStakedTokenId = 999;

        vm.prank(alice);
        vm.expectRevert();
        stakingContract.claimReward(address(nft), nonStakedTokenId);
    }

    function testClaimReward_RevertForNonOwner() public {
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);

        vm.prank(bob); // not the staker
        vm.expectRevert();
        stakingContract.claimReward(address(nft), tokenId);
    }

    function testDepositReward_RevertForInsufficientAllowance() public {
        uint256 amount = 10 ether;
        vm.prank(alice);
        vm.expectRevert();
        stakingContract.depositReward(amount);
    }

    function testStakingWithDifferentNFTContracts() public {
        // Add sufficient rewards to the staking contract
        rewardToken.mint(address(stakingContract), 100 ether);

        // Deploy a second NFT contract for this test
        vm.startPrank(deployer);
        SPNFT secondNFT = new SPNFT(deployer);
        secondNFT.configureStrategy(address(inCollectionStrategy), true, true);

        // Approve the second NFT in RevealModule first
        revealModule.setNFTContractApproval(address(secondNFT), true);

        // Then approve it in StakingContract
        stakingContract.setNFTContractApproval(address(secondNFT), true);
        vm.stopPrank();

        // Mint and stake tokens from both contracts
        uint256 tokenId1 = mintNFT(alice);
        revealNFT(alice, tokenId1);

        vm.deal(alice, 1 ether);
        vm.startPrank(alice);
        uint256 tokenId2 = secondNFT.nextTokenId();
        secondNFT.mint{value: secondNFT.mintPrice()}();
        vm.stopPrank();

        // Reveal the second NFT
        vm.startPrank(alice);
        revealModule.reveal(address(secondNFT), tokenId2);
        vm.stopPrank();

        // Get next request ID and fulfill randomness with this ID
        uint256 requestId = vrfCoordinator.nextRequestId() - 1;
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId, address(revealModule));

        // Stake both NFTs
        vm.startPrank(alice);
        nft.approve(address(stakingContract), tokenId1);
        stakingContract.stake(address(nft), tokenId1);
        secondNFT.approve(address(stakingContract), tokenId2);
        stakingContract.stake(address(secondNFT), tokenId2);
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 30 days);

        // Unstake and verify both NFTs return correctly
        vm.startPrank(alice);
        stakingContract.unstake(address(nft), tokenId1);
        stakingContract.unstake(address(secondNFT), tokenId2);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId1), alice, "First NFT should return to Alice");
        assertEq(secondNFT.ownerOf(tokenId2), alice, "Second NFT should return to Alice");
    }

    function testClaimRewardMultipleTimes() public {
        // Mint, reveal, and stake an NFT
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);

        // Ensure staking contract has sufficient rewards
        rewardToken.mint(address(stakingContract), 100 ether);

        // First reward period (30 days)
        vm.warp(block.timestamp + 30 days);

        uint256 aliceBalanceBefore = rewardToken.balanceOf(alice);

        // First claim
        vm.prank(alice);
        stakingContract.claimReward(address(nft), tokenId);

        uint256 firstReward = rewardToken.balanceOf(alice) - aliceBalanceBefore;
        assertTrue(firstReward > 0, "First reward should be positive");

        // Second reward period (45 days)
        vm.warp(block.timestamp + 45 days);

        uint256 aliceBalanceAfterFirstClaim = rewardToken.balanceOf(alice);

        // Second claim
        vm.prank(alice);
        stakingContract.claimReward(address(nft), tokenId);

        uint256 secondReward = rewardToken.balanceOf(alice) - aliceBalanceAfterFirstClaim;
        assertTrue(secondReward > 0, "Second reward should be positive");

        // Verify second reward is larger than first due to longer period
        assertTrue(secondReward > firstReward, "Second reward should be larger due to longer staking period");

        // Final unstake
        vm.prank(alice);
        stakingContract.unstake(address(nft), tokenId);
        assertEq(nft.ownerOf(tokenId), alice, "NFT should return to Alice after unstaking");
    }

    function testStakingWithExtremeTimeperiods() public {
        // Mint and stake NFT
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);

        // Ensure staking contract has sufficient rewards
        rewardToken.mint(address(stakingContract), 1000 ether);

        // Test very short staking period (1 minute)
        vm.warp(block.timestamp + 1 minutes);

        (, uint96 stakedAt) = stakingContract.getStakeInfo(address(nft), tokenId);
        uint256 shortPeriodReward = stakingContract.calculateReward(stakedAt);

        // Even very short periods should yield non-zero rewards
        assertTrue(shortPeriodReward > 0, "Even short staking periods should yield rewards");

        // Test very long staking period (10 years)
        vm.warp(block.timestamp + 10 * 365 days);

        uint256 longPeriodReward = stakingContract.calculateReward(stakedAt);
        assertTrue(longPeriodReward > 0, "Long staking periods should yield rewards");

        // Calculate expected reward for 10 years
        uint256 baseAmount = 10 ** rewardToken.decimals();
        uint256 expectedReward = (baseAmount * 5 * 10 * 365 days) / (100 * 365 days);
        // Allow for some rounding differences
        assertApproxEqAbs(longPeriodReward, expectedReward, 1e16, "Long-term reward calculation should match formula");

        // Claim rewards and verify
        uint256 aliceBalanceBefore = rewardToken.balanceOf(alice);
        vm.prank(alice);
        stakingContract.unstakeAndClaimReward(address(nft), tokenId);
        uint256 actualReward = rewardToken.balanceOf(alice) - aliceBalanceBefore;

        assertApproxEqAbs(actualReward, longPeriodReward, 1e10, "Claimed reward should match calculated amount");
    }

    function testRewardDistributionWithNewDeposits() public {
        // Add initial rewards
        rewardToken.mint(address(stakingContract), 100 ether);

        // Mint and stake an NFT
        uint256 tokenId = mintNFT(alice);
        revealNFT(alice, tokenId);
        stakeNFT(alice, tokenId);

        // Fast forward 15 days
        vm.warp(block.timestamp + 15 days);

        // Add more rewards to the staking pool
        vm.startPrank(deployer);
        rewardToken.approve(address(stakingContract), 50 ether);
        stakingContract.depositReward(50 ether);
        vm.stopPrank();

        // Fast forward 15 more days (total 30 days)
        vm.warp(block.timestamp + 15 days);

        // Calculate expected reward for 30 days
        (, uint96 stakedAt) = stakingContract.getStakeInfo(address(nft), tokenId);
        uint256 expectedReward = stakingContract.calculateReward(stakedAt);

        // Track balances before claiming
        uint256 aliceBalanceBefore = rewardToken.balanceOf(alice);

        // Claim rewards
        vm.prank(alice);
        stakingContract.unstakeAndClaimReward(address(nft), tokenId);
        uint256 actualReward = rewardToken.balanceOf(alice) - aliceBalanceBefore;

        // Verify reward was received
        assertTrue(actualReward > 0, "Alice should receive rewards");

        // Verify reward is based on staking time (aproximately)
        assertEq(actualReward, expectedReward, "Received reward should match calculated amount");
    }
}
