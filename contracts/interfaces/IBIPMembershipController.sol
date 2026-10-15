// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBIPMembershipController
/// @notice Interface for BIP4444 membership controller (design sketch only).
/// @dev This is a planning artifact. Do not deploy until audit gates are complete.
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

    function register(uint256 agentId) external;

    function revoke(uint256 agentId) external;

    function pause() external;

    function unpause() external;

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
}
