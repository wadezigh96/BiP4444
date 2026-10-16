// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBIPMembershipController} from "../interfaces/IBIPMembershipController.sol";
import {IERC8004Identity} from "../interfaces/IERC8004Identity.sol";

/// @title BIPMembershipController
/// @notice Pre-audit membership registry referencing existing ERC-8004 identities.
/// @dev NOT production-ready. Do not deploy to mainnet until all audit gates pass.
///      Payment verification remains an off-chain responsibility; registerFor must
///      only be called by a backend relayer after confirmed B402 settlement.
contract BIPMembershipController is IBIPMembershipController {
    uint256 private constant _MAX_MEMBERS = 4444;

    IERC8004Identity public immutable identityRegistry;

    struct Membership {
        uint256 membershipId;
        address registeredBy;
        uint64 registeredAt;
        bool active;
    }

    mapping(uint256 => Membership) private _memberships;
    mapping(address => bool) public isRelayer;

    uint256 private _nextMembershipId = 1;
    uint256 private _activeMemberCount;

    address public owner;
    bool public paused;

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

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRelayer() {
        if (!isRelayer[msg.sender]) revert NotRelayer();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedError();
        _;
    }

    constructor(address identityRegistry_) {
        if (identityRegistry_ == address(0)) revert ZeroAddress();
        identityRegistry = IERC8004Identity(identityRegistry_);
        owner = msg.sender;
    }

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

    /// @notice Self-service registration; caller must own the ERC-8004 identity.
    function register(uint256 agentId) external override whenNotPaused {
        if (agentId == 0) revert ZeroAgentId();
        address agentOwner = identityRegistry.ownerOf(agentId);
        if (agentOwner != msg.sender) revert NotAgentOwner();
        _register(agentId, agentOwner, msg.sender);
    }

    /// @notice Backend-relayer registration after confirmed payment settlement.
    /// @dev Contract cannot verify off-chain x402 settlement; relayer compromise is a
    ///      critical trust risk. Never grant this role to a public or user-controlled key.
    function registerFor(uint256 agentId) external override onlyRelayer whenNotPaused {
        if (agentId == 0) revert ZeroAgentId();
        address agentOwner = identityRegistry.ownerOf(agentId);
        _register(agentId, agentOwner, msg.sender);
    }

    function _register(uint256 agentId, address agentOwner, address operator) internal {
        Membership storage m = _memberships[agentId];
        if (m.active) revert AlreadyMember();
        if (_activeMemberCount >= _MAX_MEMBERS) revert CapReached();

        uint256 newId = _nextMembershipId++;
        m.membershipId = newId;
        // Store the identity owner, while the event records the actual operator.
        m.registeredBy = agentOwner;
        m.registeredAt = uint64(block.timestamp);
        m.active = true;

        unchecked {
            _activeMemberCount += 1;
        }

        emit MembershipRegistered(agentId, newId, operator);
    }

    /// @notice Owner-controlled allowlist for the backend relayer.
    function setRelayer(address relayer, bool enabled) external override onlyOwner {
        if (relayer == address(0)) revert ZeroAddress();
        isRelayer[relayer] = enabled;
        emit RelayerUpdated(relayer, enabled);
    }

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

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
}
