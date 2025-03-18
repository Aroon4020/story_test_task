// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseTest} from "./BaseTest.sol";
import {Events} from "../src/utils/Events.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimelockTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }
    
    function testStrategy_TimelockProtection() public {
        // Start with the default (in-collection) strategy
        assertEq(revealModule.getRevealStrategy(), address(inCollectionStrategy), "Should start with in-collection strategy");
        
        // Use revealModule to schedule the operation
        vm.startPrank(deployer);
        revealModule.scheduleStrategyUpdate(address(separateCollectionStrategy));
        vm.stopPrank();
        
        // Get timelock instance
        TimelockController timelock = revealModule.timelock();

        // Prepare the function call to update the strategy
        bytes memory data = abi.encodeWithSelector(
            revealModule.executeStrategyUpdate.selector,
            address(separateCollectionStrategy)
        );
        
        // Try executing too early - should fail
        vm.startPrank(deployer);
        (bool success,) = address(timelock).call(
            abi.encodeWithSelector(
                timelock.execute.selector,
                address(revealModule),
                0,
                data,
                bytes32(0),
                revealModule.STRATEGY_UPDATE_OPERATION()
            )
        );
        vm.stopPrank();

        assertFalse(success, "Execution should fail before timelock delay");
        assertEq(revealModule.getRevealStrategy(), address(inCollectionStrategy), "Strategy shouldn't change yet");
        
        // Fast forward past timelock delay
        vm.warp(block.timestamp + timelockDelay + 1);
        
        // Execute operation
        vm.prank(deployer);
        timelock.execute(
            address(revealModule),
            0,
            data,
            bytes32(0),
            revealModule.STRATEGY_UPDATE_OPERATION()
        );
        
        // Verify strategy is updated
        assertEq(revealModule.getRevealStrategy(), address(separateCollectionStrategy), "Strategy should be updated");
    }
}
