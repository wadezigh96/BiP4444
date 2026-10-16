// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBIPMembershipController
/// @notice Interface for BIP4444 membership controller (pre-audit implementation).
/// @dev Do not deploy until all gates in docs/AUDIT_GATES.md pass.
interface IBIPMembershipController {
    function MAX_MEMBERS() external pure returns (uint256);
    function activeMemberCount() external view returns (uint256);
    function isMember(uint256 agentId) external view returns (bool);

    function membershipOf(uint256 agentId)
        external
        view
        returns (uint256 membershipId, address registeredBy, uint64 registeredAt, bool active);

    function register(uint256 agentId) external;
    function registerFor(uint256 agentId) external;
    function setRelayer(address relayer, bool enabled) external;
    function revoke(uint256 agentId) external;
    function pause() external;
    function unpause() external;

    event MembershipRegistered(uint256 indexed agentId, uint256 indexed membershipId, address indexed registrant);
    event MembershipRevoked(uint256 indexed agentId, uint256 indexed membershipId, address indexed by);
    event RelayerUpdated(address indexed relayer, bool enabled);
    event Paused(address account);
    event Unpaused(address account);
}
