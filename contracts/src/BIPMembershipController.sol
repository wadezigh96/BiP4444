// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBIPMembershipController} from "../interfaces/IBIPMembershipController.sol";
import {IERC8004Identity} from "../interfaces/IERC8004Identity.sol";

/// @title BIPMembershipController
/// @notice Skeleton implementation of BIP4444 membership controller.
/// @dev PLANNING / PRE-AUDIT ARTIFACT ONLY.
///      - Do NOT deploy to mainnet until all gates in docs/AUDIT_GATES.md pass.
///      - Open questions (revoke policy, ownership change handling, x402 proof)
///        must be resolved before finalizing this contract.
///      - Access control, pause, and admin model are placeholders.
contract BIPMembershipController is IBIPMembershipController {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    /// @dev Hard cap of active BIP memberships. Exposed via MAX_MEMBERS().
    uint256 private constant _MAX_MEMBERS = 4444;

    // -------------------------------------------------------------------------
    // Immutable / configuration
    // -------------------------------------------------------------------------
    IERC8004Identity public immutable identityRegistry;

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------
    struct Membership {
        uint256 membershipId;
        address registeredBy;
        uint64 registeredAt;
        bool active;
    }

    /// @dev agentId => Membership
    mapping(uint256 => Membership) private _memberships;

    /// @dev Sequential membership ID (starts at 1)
    uint256 private _nextMembershipId = 1;

    /// @dev Number of currently active memberships
    uint256 private _activeMemberCount;

    /// @dev Simple owner for skeleton; replace with AccessControl / multisig later
    address public owner;

    bool public paused;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error NotOwner();
    error PausedError();
    error NotPausedError();
    error CapReached();
    error AlreadyMember();
    error NotMember();
    error NotAgentOwner();
    error ZeroAddress();
    error ZeroAgentId();

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedError();
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor(address identityRegistry_) {
        if (identityRegistry_ == address(0)) revert ZeroAddress();
        identityRegistry = IERC8004Identity(identityRegistry_);
        owner = msg.sender;
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------
    function MAX_MEMBERS() external pure override returns (uint256) {
        return _MAX_MEMBERS;
    }

    function activeMemberCount() external view override returns (uint256) {
        return _activeMemberCount;
    }

    function isMember(uint256 agentId) external view override returns (bool) {
        return _memberships[agentId].active;
    }

    function membershipOf(uint256 agentId)
        external
        view
        override
        returns (uint256 membershipId, address registeredBy, uint64 registeredAt, bool active)
    {
        Membership storage m = _memberships[agentId];
        return (m.membershipId, m.registeredBy, m.registeredAt, m.active);
    }

    // -------------------------------------------------------------------------
    // Registration
    // -------------------------------------------------------------------------
    /// @notice Register an ERC-8004 agent as a BIP member.
    /// @dev Current policy (skeleton):
    ///      - Caller must be the current ownerOf(agentId) on the identity registry.
    ///      - Cap and uniqueness enforced on-chain.
    ///      - Payment verification (x402) is NOT implemented yet.
    function register(uint256 agentId) external override whenNotPaused {
        if (agentId == 0) revert ZeroAgentId();

        // Ownership check against ERC-8004
        address agentOwner = identityRegistry.ownerOf(agentId);
        if (agentOwner != msg.sender) revert NotAgentOwner();

        Membership storage m = _memberships[agentId];
        if (m.active) revert AlreadyMember();

        if (_activeMemberCount >= _MAX_MEMBERS) revert CapReached();

        uint256 newId = _nextMembershipId++;
        m.membershipId = newId;
        m.registeredBy = msg.sender;
        m.registeredAt = uint64(block.timestamp);
        m.active = true;

        unchecked {
            _activeMemberCount += 1;
        }

        emit MembershipRegistered(agentId, newId, msg.sender);
    }

    // -------------------------------------------------------------------------
    // Status management (policy still open)
    // -------------------------------------------------------------------------
    /// @notice Revoke membership. Skeleton: only contract owner can revoke.
    /// @dev Final policy (member self-revoke vs admin-only) must be decided.
    function revoke(uint256 agentId) external override onlyOwner whenNotPaused {
        Membership storage m = _memberships[agentId];
        if (!m.active) revert NotMember();

        m.active = false;
        unchecked {
            _activeMemberCount -= 1;
        }

        emit MembershipRevoked(agentId, m.membershipId, msg.sender);
    }

    function pause() external override onlyOwner {
        if (paused) revert PausedError();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external override onlyOwner {
        if (!paused) revert NotPausedError();
        paused = false;
        emit Unpaused(msg.sender);
    }

    // -------------------------------------------------------------------------
    // Admin helpers (skeleton)
    // -------------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
}
