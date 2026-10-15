// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Minimal ERC-8004 Identity Registry interface used by BIP4444
/// @dev Subset only. Full ABI may contain additional functions/events.
interface IERC8004Identity {
    /// @notice Returns the owner of the agent identity (ERC-721 style).
    function ownerOf(uint256 agentId) external view returns (address);

    /// @notice Optional convenience view (may or may not exist on all deployments).
    /// Prefer ownerOf for ownership checks.
    function getAgent(uint256 agentId)
        external
        view
        returns (address owner, string memory metadataURI, uint256 registeredAt);
}
