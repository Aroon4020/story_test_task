// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./BaseTest.sol";

contract AccessControlTest is BaseTest {
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
}
