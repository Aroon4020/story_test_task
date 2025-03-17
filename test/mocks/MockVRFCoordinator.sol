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
    
    // Track the next request ID to use
    uint256 public nextRequestId = 1;
    
    // Keep track of requests that need fulfillment
    mapping(uint256 => bool) public pendingRequests;
    
    constructor() {}
    
    // Function to mock subscription creation
    function setupConsumer() external pure returns (uint64) {
        return 1; // Always return 1 for testing
    }
    
    // Function to setup a consumer for a subscription
    function setConsumer(uint64, address consumer) external {
        // Store default consumer for convenience
        s_consumers[0] = VRFConsumerBaseV2Plus(consumer);
    }
    
    // Mock the VRF request function
    function requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest calldata
    ) external returns (uint256) {
        // Use the next available request ID
        uint256 requestId = nextRequestId;
        nextRequestId++;
        
        // Store the consumer for callback
        s_consumers[requestId] = VRFConsumerBaseV2Plus(msg.sender);
        pendingRequests[requestId] = true;
        
        return requestId;
    }
    
    // Function to manually trigger the callback for a specific request
    function fulfillRandomness(uint256 requestId, address consumerOverride) public {
        // Get the consumer for this request ID or use the override if needed
        VRFConsumerBaseV2Plus consumer = consumerOverride != address(0) 
            ? VRFConsumerBaseV2Plus(consumerOverride) 
            : s_consumers[requestId];
            
        require(address(consumer) != address(0), "Consumer not set");
        
        // Use fixed random values for testing
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        
        // Call the consumer with random words
        consumer.rawFulfillRandomWords(requestId, randomWords);
        
        // Mark as fulfilled
        pendingRequests[requestId] = false;
    }
    
    // Function to fulfill all pending requests
    function fulfillAllPending(address defaultConsumer) external {
        for (uint256 i = 1; i < nextRequestId; i++) {
            if (pendingRequests[i]) {
                fulfillRandomness(i, defaultConsumer);
            }
        }
    }
}
