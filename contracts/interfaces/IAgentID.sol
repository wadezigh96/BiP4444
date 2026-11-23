// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Minimal Agent ID interface used by BIP4444
/// @notice Agent ID is the on-chain name of a Binance Agentic Wallet
///         (form: name.ai), issued as a non-transferable ERC-721 by
///         SPACE ID on BNB Smart Chain.
/// @dev Canonical BSC mainnet deployment:
///      0x60b9262456de011f7d15a54cdd8c48baaa8b022f
///      (contract name "SPACE ID Agent ID", symbol "AI", ERC-721,
///      non-transferable). Per the Binance Agent ID Hackathon rules, the
///      supported way to check whether an address holds an Agent ID is
///      `balanceOf(address) > 0`. Token IDs are intentionally NOT used:
///      each user may claim only one Agent ID and it cannot be transferred,
///      so a balance check is the complete ownership test.
interface IAgentID {
    /// @notice Returns how many Agent IDs an address holds (0 or 1 in practice).
    function balanceOf(address owner) external view returns (uint256);
}
