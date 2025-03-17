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
        
        // Get timelock instance
        TimelockController timelock = revealModule.timelock();
        
        vm.startPrank(deployer);
        
        // Prepare the function call to update the strategy
        bytes memory data = abi.encodeWithSelector(
            revealModule.executeStrategyUpdate.selector,
            address(separateCollectionStrategy)
        );
        
        // Schedule the operation via timelock
        timelock.schedule(
            address(revealModule),
            0,
            data,
            bytes32(0),
            revealModule.STRATEGY_UPDATE_OPERATION(),
            timelock.getMinDelay()
        );
        vm.stopPrank();
        
        // Try executing too early - use a different approach to verify failure
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
        
        // Should fail because delay hasn't passed
        assertFalse(success, "Execution should fail before timelock delay");
        
        // Verify strategy is still unchanged
        assertEq(revealModule.getRevealStrategy(), address(inCollectionStrategy), "Strategy shouldn't change yet");
        
        // Fast forward past timelock delay
        vm.warp(block.timestamp + timelockDelay + 1);
        
        // Now execution should succeed
        vm.prank(deployer);
        timelock.execute(
            address(revealModule),
            0,
            data,
            bytes32(0),
            revealModule.STRATEGY_UPDATE_OPERATION()
        );
        
        // Verify strategy has been updated
        assertEq(revealModule.getRevealStrategy(), address(separateCollectionStrategy), "Strategy should be updated");
    }
}
