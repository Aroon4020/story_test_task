// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * Simple VRF coordinator mock for testing
 */
contract MockVRFCoordinator {
    // Map of consumers for callbacks
    mapping(uint256 => VRFConsumerBaseV2Plus) public s_consumers;
    
    // Default request ID for testing
    uint256 public constant FIXED_REQUEST_ID = 1;
    
    constructor() {}
    
    // Function to mock subscription creation
    function setupConsumer() external pure returns (uint64) {
        return 1; // Always return 1 for testing
    }
    
    // Function to setup a consumer for a subscription
    function setConsumer(uint64, address consumer) external {
        // Store the consumer for the fixed request ID
        s_consumers[FIXED_REQUEST_ID] = VRFConsumerBaseV2Plus(consumer);
    }
    
    // Mock the VRF request function
    function requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest calldata
    ) external returns (uint256) {
        // Store the consumer for callback
        s_consumers[FIXED_REQUEST_ID] = VRFConsumerBaseV2Plus(msg.sender);
        return FIXED_REQUEST_ID;
    }
    
    // Function to manually trigger the callback
    function fulfillRandomness(uint256 requestId, address) external {
        // Use fixed random values for testing
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        
        // Ensure the consumer is set
        require(address(s_consumers[requestId]) != address(0), "Consumer not set");
        
        // Call the consumer with random words
        s_consumers[requestId].rawFulfillRandomWords(requestId, randomWords);
    }
}
