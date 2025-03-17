// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Events} from "../src/utils/Events.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; // Add this import
import {MetadataGenerator} from "../src/strategies/libraries/MetadataGenerator.sol";
// Add VRF interface import
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol"; // Added this import

// Import contracts with aliases to avoid naming conflicts
import {SPNFT} from "../src/SPNFT.sol";
import {RevealModule} from "../src/RevealModule.sol";
import {RevealedNFT} from "../src/RevealedNFT.sol";
import {InCollectionRevealStrategy} from "../src/strategies/InCollectionRevealStrategy.sol";
import {SeparateCollectionRevealStrategy} from "../src/strategies/SeparateCollectionRevealStrategy.sol";
import {StakingContract} from "../src/staking/StakingContract.sol";
import {MockVRFCoordinator} from "./mocks/MockVRFCoordinator.sol";
import {TestERC20} from "./mocks/TestERC20.sol";

contract BaseTest is Test, ERC721Holder {
    // Contracts
    SPNFT public nft;
    RevealModule public revealModule;
    RevealedNFT public revealedNFT;
    InCollectionRevealStrategy public inCollectionStrategy;
    SeparateCollectionRevealStrategy public separateCollectionStrategy;
    StakingContract public stakingContract;
    MockVRFCoordinator public vrfCoordinator;
    TestERC20 public rewardToken;
    
    // Test accounts
    address public deployer;
    address public alice;
    address public bob;
    
    // VRF parameters
    bytes32 public keyHash = bytes32(uint256(1));
    uint64 public subscriptionId = 1;
    uint16 public requestConfirmations = 3;
    uint32 public callbackGasLimit = 200000;
    uint32 public numWords = 1;
    uint256 public timelockDelay = 2 days;
    
    // Setup
    function setUp() public virtual {
        // Use vm.addr to generate canonical addresses
        deployer = vm.addr(1);
        alice = vm.addr(2);
        bob = vm.addr(3);
        
        vm.startPrank(deployer);
        
        // Deploy mock contracts with proper VRF setup
        vrfCoordinator = new MockVRFCoordinator();
        rewardToken = new TestERC20("Reward Token", "RWD");
        
        // Create subscription and fund it
        subscriptionId = vrfCoordinator.setupConsumer();
        
        // Deploy main contracts
        nft = new SPNFT(deployer);
        revealedNFT = new RevealedNFT(deployer);
        
        // Deploy strategies (use true strategy in actual test)
        inCollectionStrategy = new InCollectionRevealStrategy(deployer);
        separateCollectionStrategy = new SeparateCollectionRevealStrategy(address(revealedNFT), deployer);
        
        // Deploy and configure reveal module
        revealModule = new RevealModule(
            address(vrfCoordinator),
            address(inCollectionStrategy), // Default to in-collection strategy
            uint64(subscriptionId), // Make sure this is cast to uint64
            keyHash,
            requestConfirmations,
            callbackGasLimit,
            numWords,
            timelockDelay,
            deployer
        );
        
        // Add required timelock roles to deployer for testing
        TimelockController timelock = revealModule.timelock();
        
        // Grant PROPOSER_ROLE and CANCELLER_ROLE to deployer
        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 CANCELLER_ROLE = timelock.CANCELLER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        
        // Grant roles - REMOVED vm.prank() calls since we're already in vm.startPrank(deployer)
        timelock.grantRole(PROPOSER_ROLE, deployer);
        timelock.grantRole(PROPOSER_ROLE, address(revealModule)); // Add this line to give RevealModule the PROPOSER_ROLE
        timelock.grantRole(CANCELLER_ROLE, deployer);
        timelock.grantRole(CANCELLER_ROLE, address(revealModule)); // Add this line to give RevealModule the CANCELLER_ROLE
        timelock.grantRole(EXECUTOR_ROLE, address(0)); // Allow anyone to execute
        
        // Setup approvals and connections - use new API
        // Configure the SPNFT to use the InCollectionStrategy directly
        nft.configureStrategy(address(inCollectionStrategy), true, true);        
        // Setup strategy to use the reveal module
        inCollectionStrategy.setRevealModule(address(revealModule));
        separateCollectionStrategy.setRevealModule(address(revealModule));
        
        // Deploy staking contract
        stakingContract = new StakingContract(
            address(rewardToken),
            address(revealModule),
            deployer
        );
        
        // Setup staking approvals
        revealModule.setNFTContractApproval(address(nft), true);
        stakingContract.setNFTContractApproval(address(nft), true);
        
        // Fund reward token
        rewardToken.mint(address(stakingContract), 1000 ether);
        vrfCoordinator.setConsumer(subscriptionId, address(revealModule));
        vm.stopPrank();
    }
    
    // Helper methods for common operations
    function mintNFT(address to) internal returns (uint256) {
        vm.deal(to, 1 ether); // Give ETH for minting
        
        // Get the token ID before minting
        uint256 tokenId = nft.nextTokenId();
        
        console.log("Minting token", tokenId);
        console.log("Mint to address:", to);
        
        vm.startPrank(to);
        nft.mint{value: nft.mintPrice()}();
        vm.stopPrank();
        
        // After minting, verify token exists and ownership
        address owner = nft.ownerOf(tokenId);
        console.log("Token", tokenId, "owner:", owner);
        
        // Don't assert ownership here, just check and return
        return tokenId;
    }
    
    function revealNFT(address owner, uint256 tokenId) internal {
        vm.prank(owner);
        revealModule.reveal(address(nft), tokenId);
        uint256 requestId = 1;
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomness(requestId, address(revealModule));
        assertTrue(revealModule.isRevealed(address(nft), tokenId), "Token should be revealed in RevealModule");
        assertTrue(nft.revealed(tokenId), "Token should be revealed in NFT contract");
    }
    
    function stakeNFT(address owner, uint256 tokenId) internal {
        vm.startPrank(owner);
        nft.approve(address(stakingContract), tokenId);
        stakingContract.stake(address(nft), tokenId);
        vm.stopPrank();
    }
}
