// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBIPMembershipController
/// @notice Interface for BIP4444 membership controller.
/// @dev Planning / pre-audit. Do not deploy until all gates in docs/AUDIT_GATES.md pass.
interface IBIPMembershipController {
    function MAX_MEMBERS() external pure returns (uint256);

    function activeMemberCount() external view returns (uint256);

    function isMember(uint256 agentId) external view returns (bool);

    function membershipOf(uint256 agentId)
        external
        view
        returns (
            uint256 membershipId,
            address registeredBy,
            uint64 registeredAt,
            bool active
        );

    /// @notice Register as the current ERC-8004 owner of the agent.
    function register(uint256 agentId) external;

    /// @notice Register on behalf of an agent (Path A — backend relayer after successful x402 settle).
    /// @dev Must only be callable by the designated relayer. Does not check payment on-chain.
    function registerFor(uint256 agentId) external;

    function revoke(uint256 agentId) external;

    function pause() external;

    function unpause() external;

    function setRelayer(address newRelayer) external;

    event MembershipRegistered(
        uint256 indexed agentId,
        uint256 indexed membershipId,
        address indexed registrant
    );

    event MembershipRevoked(
        uint256 indexed agentId,
        uint256 indexed membershipId,
        address indexed by
    );

    event Paused(address account);
    event Unpaused(address account);
    event RelayerUpdated(address indexed previousRelayer, address indexed newRelayer);
}
