// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library TransferHelper {
    // Custom error for transfer failures
    error ETHTransferFailed(address to, uint256 amount);
    
    /**
     * @notice Safely sends ETH to an address
     * @param to Recipient of the ETH
     * @param amount Amount of ETH to send
     * @return success Whether the transfer succeeded
     */
    function safeTransferETH(address to, uint256 amount) internal returns (bool) {
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert ETHTransferFailed(to, amount);
        return success;
    }
}
