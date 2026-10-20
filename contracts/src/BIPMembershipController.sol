// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBIPMembershipController} from "../interfaces/IBIPMembershipController.sol";
import {IERC8004Identity} from "../interfaces/IERC8004Identity.sol";

/// @title BIPMembershipController
/// @notice Membership controller for BIP4444 (Path A: owner register + relayer registerFor).
/// @dev PLANNING / PRE-AUDIT ARTIFACT ONLY.
///      - Do NOT deploy to mainnet until all gates in docs/AUDIT_GATES.md pass.
///      - Open questions (revoke policy, ownership change handling, on-chain payment proof)
///        remain; see docs/MEMBERSHIP_CONTROLLER.md.
///      - Access control is still simple (owner + single relayer). Replace with
///        AccessControl / multisig before production.
///      - Payment (x402/B402) is NOT verified on-chain. Relayer must only call
///        registerFor after successful off-chain settlement + ledger record.
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
        address registeredBy; // ERC-8004 owner at registration time
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

    /// @dev Single relayer authorized to call registerFor (Path A).
    ///      Set to address(0) to disable relayer path.
    address public relayer;

    bool public paused;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error NotOwner();
    error NotRelayer();
    error PausedError();
    error NotPausedError();
    error CapReached();
    error AlreadyMember();
    error NotMember();
    error NotAgentOwner();
    error ZeroAddress();
    error ZeroAgentId();
    error AgentDoesNotExist();

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRelayer() {
        if (msg.sender != relayer || relayer == address(0)) revert NotRelayer();
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
    // Registration (owner path)
    // -------------------------------------------------------------------------
    /// @notice Register an ERC-8004 agent as a BIP member (caller must be current owner).
    /// @dev Payment verification (x402) is NOT implemented on-chain.
    function register(uint256 agentId) external override whenNotPaused {
        if (agentId == 0) revert ZeroAgentId();

        address agentOwner = identityRegistry.ownerOf(agentId);
        if (agentOwner != msg.sender) revert NotAgentOwner();

        _register(agentId, agentOwner, msg.sender);
    }

    // -------------------------------------------------------------------------
    // Registration (Path A — relayer)
    // -------------------------------------------------------------------------
    /// @notice Register an agent on behalf of its owner (backend relayer after x402 settle).
    /// @dev - Only the designated relayer may call this.
    ///      - Agent must exist (ownerOf must not revert).
    ///      - Cap and uniqueness still enforced.
    ///      - registeredBy stores the current ERC-8004 owner (not the relayer).
    ///      - Event registrant = relayer (msg.sender).
    ///      - Payment is verified off-chain by the relayer before this call.
    function registerFor(uint256 agentId) external override onlyRelayer whenNotPaused {
        if (agentId == 0) revert ZeroAgentId();

        address agentOwner = identityRegistry.ownerOf(agentId);
        // ownerOf reverts if agent does not exist (per mock + real ERC-8004 behaviour)

        _register(agentId, agentOwner, msg.sender);
    }

    function _register(uint256 agentId, address agentOwner, address registrant) internal {
        Membership storage m = _memberships[agentId];
        if (m.active) revert AlreadyMember();

        if (_activeMemberCount >= _MAX_MEMBERS) revert CapReached();

        uint256 newId = _nextMembershipId++;
        m.membershipId = newId;
        m.registeredBy = agentOwner;
        m.registeredAt = uint64(block.timestamp);
        m.active = true;

        unchecked {
            _activeMemberCount += 1;
        }

        emit MembershipRegistered(agentId, newId, registrant);
    }

    // -------------------------------------------------------------------------
    // Status management
    // -------------------------------------------------------------------------
    /// @notice Revoke membership. Current skeleton: only contract owner.
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
    // Admin helpers
    // -------------------------------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    /// @notice Set or update the Path A relayer address.
    /// @dev Set to address(0) to disable registerFor.
    function setRelayer(address newRelayer) external override onlyOwner {
        address previous = relayer;
        relayer = newRelayer;
        emit RelayerUpdated(previous, newRelayer);
    }
}
