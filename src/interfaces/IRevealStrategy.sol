// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRevealStrategy {
    /// @notice Executes the reveal logic for a given token using the provided randomness.
    function reveal(uint256 tokenId, uint256 randomResult) external returns (bool);
}
