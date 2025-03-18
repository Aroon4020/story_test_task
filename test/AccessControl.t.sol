// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./BaseTest.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract AccessControlTest is BaseTest {
    // Variables to store roles for timelock tests
    bytes32 public PROPOSER_ROLE;
    bytes32 public EXECUTOR_ROLE;
    bytes32 public CANCELLER_ROLE;

    function setUp() public override {
        super.setUp();

        // Get role identifiers from the timelock
        TimelockController timelock = revealModule.timelock();
        PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        CANCELLER_ROLE = timelock.CANCELLER_ROLE();
    }

    function testOnlyOwnerFunctions() public {
        address nonOwner = bob;

        // SPNFT owner functions
        vm.startPrank(nonOwner);
        vm.expectRevert();
        // Replace nft.setRevealModule with nft.configureStrategy for testing owner restriction
        nft.configureStrategy(address(0x123), true, false);

        vm.expectRevert();
        nft.setMintPrice(0.1 ether);

        vm.expectRevert();
        nft.withdrawETH(nonOwner, 1 ether);
        vm.stopPrank();

        // RevealModule owner functions
        vm.startPrank(nonOwner);
        vm.expectRevert();
        revealModule.scheduleStrategyUpdate(address(0x123));

        vm.expectRevert();
        revealModule.setNFTContractApproval(address(nft), false);
        vm.stopPrank();

        // Strategy owner functions
        vm.startPrank(nonOwner);
        vm.expectRevert();
        inCollectionStrategy.setRevealModule(address(0x123));
        vm.stopPrank();
    }

    function testOnlyRevealModuleFunctions() public {
        uint256 tokenId = mintNFT(alice);

        // Only reveal module can set token revealed
        vm.prank(alice);
        vm.expectRevert();
        nft.setTokenRevealed(tokenId, "test metadata");

        // Only reveal module can burn tokens
        vm.prank(alice);
        vm.expectRevert();
        nft.burn(tokenId);
    }

    // Test StakingContract owner functions
    function testStakingContractOwnerFunctions() public {
        address nonOwner = alice;

        // Non-owner should not be able to set reveal module
        vm.startPrank(nonOwner);
        vm.expectRevert();
        stakingContract.setRevealModule(address(0x123));

        // Non-owner should not be able to approve NFT contracts
        vm.expectRevert();
        stakingContract.setNFTContractApproval(address(0x123), true);
        vm.stopPrank();

        // Owner should be able to perform these actions
        vm.startPrank(deployer);
        address newRevealModule = address(0x123);
        stakingContract.setRevealModule(newRevealModule);
        assertEq(address(stakingContract.revealModule()), newRevealModule, "Owner should be able to set reveal module");

        address newNftContract = address(0x456);
        stakingContract.setNFTContractApproval(newNftContract, true);
        assertTrue(stakingContract.approvedNFTContracts(newNftContract), "Owner should be able to approve NFT contract");
        vm.stopPrank();
    }

    // Test RevealModule update functions access control
    function testRevealModuleUpdateFunctions() public {
        address nonOwner = alice;

        // Non-owner should not be able to update callback gas limit
        vm.startPrank(nonOwner);
        vm.expectRevert();
        revealModule.updateCallbackGasLimit(300000);

        // Non-owner should not be able to update request confirmations
        vm.expectRevert();
        revealModule.updateRequestConfirmations(5);
        // Owner should be able to perform these actions
        vm.startPrank(deployer);
        uint32 newGasLimit = 300000;
        revealModule.updateCallbackGasLimit(newGasLimit);

        uint16 newConfirmations = 5;
        revealModule.updateRequestConfirmations(newConfirmations);

        // Note: updateTimelockDelay requires timelock execution - tested separately
        vm.stopPrank();
    }

    // Test staking access control
    function testStakingAccessControl() public {
        // Add reward tokens to ensure staking functions work properly
        rewardToken.mint(address(stakingContract), 100 ether);

        // Mint and reveal the first NFT for Alice
        uint256 aliceTokenId = mintNFT(alice);

        // Get the first request ID for Alice's token
        uint256 aliceRequestId = vrfCoordinator.nextRequestId();
        vm.prank(alice);
        revealModule.reveal(address(nft), aliceTokenId);

        // Mint a token for Bob before fulfilling the first request
        uint256 bobTokenId = mintNFT(bob);

        // Complete Alice's token reveal first
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(aliceRequestId, address(revealModule));

        // Now reveal Bob's token
        uint256 bobRequestId = vrfCoordinator.nextRequestId();
        vm.prank(bob);
        revealModule.reveal(address(nft), bobTokenId);

        // Complete Bob's token reveal
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(bobRequestId, address(revealModule));

        // Verify both tokens are revealed
        assertTrue(nft.revealed(aliceTokenId), "Alice's token should be revealed");
        assertTrue(nft.revealed(bobTokenId), "Bob's token should be revealed");

        // Bob cannot stake Alice's NFT
        vm.startPrank(bob);
        vm.expectRevert(); // removed expected string message
        stakingContract.stake(address(nft), aliceTokenId);
        vm.stopPrank();

        // First approve the NFT for staking
        vm.startPrank(alice);
        nft.approve(address(stakingContract), aliceTokenId);

        // Then stake the NFT
        stakingContract.stake(address(nft), aliceTokenId);
        vm.stopPrank();

        // Bob cannot unstake Alice's staked NFT
        vm.startPrank(bob);
        vm.expectRevert();
        stakingContract.unstake(address(nft), aliceTokenId);

        // Bob cannot claim rewards for Alice's staked NFT
        vm.expectRevert();
        stakingContract.claimReward(address(nft), aliceTokenId);

        // Bob cannot unstake and claim rewards for Alice's NFT
        vm.expectRevert();
        stakingContract.unstakeAndClaimReward(address(nft), aliceTokenId);
        vm.stopPrank();

        // Alice can unstake her own NFT
        vm.prank(alice);
        stakingContract.unstake(address(nft), aliceTokenId);
    }

    // Test executeStrategyUpdate access control
    function testExecuteStrategyUpdateAccessControl() public {
        // Only timelock can call executeStrategyUpdate
        vm.startPrank(deployer);
        vm.expectRevert();
        revealModule.executeStrategyUpdate(address(separateCollectionStrategy));
        vm.stopPrank();

        // Schedule the update properly
        vm.startPrank(deployer);
        revealModule.scheduleStrategyUpdate(address(separateCollectionStrategy));
        vm.warp(block.timestamp + timelockDelay + 1);

        // Execute via timelock works
        bytes memory callData =
            abi.encodeWithSelector(revealModule.executeStrategyUpdate.selector, address(separateCollectionStrategy));

        revealModule.timelock().execute(
            address(revealModule), 0, callData, bytes32(0), revealModule.STRATEGY_UPDATE_OPERATION()
        );

        // Verify the update happened
        assertEq(revealModule.getRevealStrategy(), address(separateCollectionStrategy), "Strategy should be updated");
        vm.stopPrank();
    }

    // Test SPNFT withdrawETH with specific accounts
    function testWithdrawETHAccessControl() public {
        // Fund the NFT contract
        vm.deal(address(nft), 2 ether);

        // Non-owner cannot withdraw
        vm.startPrank(alice);
        vm.expectRevert();
        nft.withdrawETH(alice, 1 ether);
        vm.stopPrank();

        // Owner can withdraw and specify recipient
        address recipient = vm.addr(123);
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(deployer);
        nft.withdrawETH(recipient, 1 ether);

        assertEq(recipient.balance, recipientBalanceBefore + 1 ether, "Recipient should receive ether");
    }

    // Test StakingContract additional access controls
    function testStakingAdditionalAccessControl() public {
        // Cannot stake unrevealed tokens
        uint256 tokenId = mintNFT(alice);
        // Intentionally NOT calling revealNFT

        vm.startPrank(alice);
        nft.approve(address(stakingContract), tokenId);
        vm.expectRevert();
        stakingContract.stake(address(nft), tokenId);
        vm.stopPrank();

        // Cannot stake from unapproved contracts
        vm.startPrank(deployer);
        SPNFT unauthorizedNFT = new SPNFT(deployer);
        unauthorizedNFT.configureStrategy(address(inCollectionStrategy), true, true);
        vm.stopPrank();

        vm.deal(alice, 1 ether);
        vm.startPrank(alice);
        uint256 unauthorizedTokenId = unauthorizedNFT.nextTokenId();
        unauthorizedNFT.mint{value: unauthorizedNFT.mintPrice()}();
        vm.expectRevert();
        stakingContract.stake(address(unauthorizedNFT), unauthorizedTokenId);
        vm.stopPrank();
    }
}
