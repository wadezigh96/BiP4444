// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentID} from "../interfaces/IAgentID.sol";
import {IERC8004Identity} from "../interfaces/IERC8004Identity.sol";

/// @title BIPAgentIDGate
/// @notice Agent ID gate for BIP4444 on BNB Smart Chain, built for the
///         Binance Agent ID Hackathon (Binance Wallet x BNB Chain).
///
/// @dev How Agent ID is used (core flow, not a decorative check):
///      1. ROOT IDENTITY — an operator wallet must hold an Agent ID
///         (`balanceOf(wallet) > 0` on the canonical Agent ID contract)
///         before it can bind its ERC-8004 agent identity to BIP4444.
///      2. DELEGATED CAPABILITIES — a bound operator can grant narrowly
///         scoped, expiring capabilities to delegate addresses (e.g. a
///         sub-agent). Scopes are opaque `bytes32` values; applications
///         should use `keccak256("domain:action")`, e.g.
///         `keccak256("bip4444:alerts:receive")`.
///      3. LIVE AUTHORIZATION — `isAuthorized` re-checks Agent ID
///         ownership at call time. If the grantor no longer holds an
///         Agent ID, or unbinds, or the capability expires / is revoked,
///         authorization fails closed.
///
///      Safety / hackathon red-line compliance:
///      - This contract holds NO user assets, has NO payable functions,
///        NO transfer / approval logic, and never asks for or stores
///        seed phrases, private keys, API secrets or pairing codes.
///      - It never bypasses user confirmation: granting a capability is
///        an explicit on-chain transaction by the grantor wallet itself.
///      - Owner permissions are disclosed and minimal: the owner can only
///        pause / unpause and transfer ownership. The owner CANNOT grant
///        or revoke user capabilities, unbind users, or move anything.
///      - Agent ID is used as an authorization root only. This contract
///        is NOT a "look up other people's wallets by name" tool: it
///        stores no name-to-address directory and exposes no name lookup.
///
///      Status: PRE-AUDIT artifact, same posture as the rest of BIP4444.
///      Do NOT treat as production-ready until docs/AUDIT_GATES.md pass.
contract BIPAgentIDGate {
    // -------------------------------------------------------------------------
    // Immutable / configuration
    // -------------------------------------------------------------------------
    /// @notice Canonical Agent ID contract (SPACE ID Agent ID, BSC mainnet).
    IAgentID public immutable agentID;

    /// @notice ERC-8004 Identity Registry used by BIP4444.
    IERC8004Identity public immutable identityRegistry;

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------
    /// @notice Number of Founding seats: the first 44 Agent ID operators.
    /// @dev Founding 44 is BIP4444's free-mint cohort — the membership fee
    ///      (5 USDT via the x402 relayer) is waived for these wallets,
    ///      enforced by the relayer checking `isFounding` on-chain. A seat
    ///      is a registry record only: NOT an NFT (BIP4444 has no second
    ///      passport NFT), non-transferable, and carries no promise of
    ///      returns — only the fee waiver and a verifiable founding badge.
    uint256 public constant FOUNDING_SEATS = 44;

    /// @notice Minimum time a freeze must stand before the operator can unfreeze.
    uint64 public constant FREEZE_COOLDOWN = 24 hours;

    struct AgentBinding {
        uint256 erc8004AgentId;
        uint64 boundAt;
        bool active;
        bool frozen;
        uint64 frozenAt;
    }

    struct Capability {
        address grantor;
        address delegate;
        bytes32 scope;
        uint64 expiresAt;
        bool revoked;
        /// @dev 0 = root capability granted by the operator.
        ///      Non-zero = attenuated sub-delegation of that parent capability:
        ///      same scope, expiry never exceeding the parent's, depth 1 only.
        uint256 parentId;
    }

    /// @dev operator wallet => guardian wallet allowed to trigger an emergency freeze
    mapping(address => address) private _guardians;

    /// @dev wallet => founding seat number (1..44), 0 = not founding
    mapping(address => uint256) private _foundingSeat;
    uint256 private _foundingCount;

    /// @dev operator wallet => binding to its ERC-8004 agent identity
    mapping(address => AgentBinding) private _bindings;

    /// @dev erc8004AgentId => operator wallet currently bound to it
    mapping(uint256 => address) private _agentWallet;

    /// @dev capabilityId => Capability (ids start at 1)
    mapping(uint256 => Capability) private _capabilities;
    uint256 private _nextCapabilityId = 1;

    /// @dev Wallets ever counted as unique Agent ID interactors
    mapping(address => bool) private _countedInteractor;

    uint256 private _uniqueAgentIDInteractors;
    uint256 private _totalCapabilityGrants;

    /// @dev Simple owner for skeleton; replace with multisig before production.
    address public owner;
    bool public paused;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event AgentRegistered(address indexed wallet, uint256 indexed erc8004AgentId);
    event AgentUnregistered(address indexed wallet, uint256 indexed erc8004AgentId);
    event CapabilityGranted(
        uint256 indexed capabilityId,
        address indexed grantor,
        address indexed delegate,
        bytes32 scope,
        uint64 expiresAt
    );
    event CapabilityRevoked(uint256 indexed capabilityId, address indexed grantor);
    event FoundingSeatClaimed(address indexed wallet, uint256 indexed seat);
    event GuardianSet(address indexed operator, address indexed guardian);
    event Frozen(address indexed operator, address indexed by);
    event Unfrozen(address indexed operator);
    event CapabilitySubDelegated(
        uint256 indexed capabilityId, uint256 indexed parentId, address indexed delegate, address subDelegate
    );
    event Paused(address account);
    event Unpaused(address account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error NotOwner();
    error PausedError();
    error NotPausedError();
    error ZeroAddress();
    error ZeroAgentId();
    error ZeroScope();
    error NotAgentOwner();
    error NoAgentID();
    error AlreadyBound();
    error AgentAlreadyBound();
    error NotBound();
    error InvalidDelegate();
    error InvalidExpiry();
    error UnknownCapability();
    error NotGrantor();
    error AlreadyRevoked();
    error FrozenError();
    error NotFrozenError();
    error NotGuardian();
    error FreezeCooldownActive();
    error NotDelegate();
    error CannotSubDelegate();
    error ExpiryExceedsParent();

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
    constructor(address agentID_, address identityRegistry_) {
        if (agentID_ == address(0) || identityRegistry_ == address(0)) revert ZeroAddress();
        agentID = IAgentID(agentID_);
        identityRegistry = IERC8004Identity(identityRegistry_);
        owner = msg.sender;
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------
    /// @notice True if `wallet` currently holds an Agent ID.
    /// @dev The real Agent ID contract reverts on balanceOf(address(0))
    ///      (standard ERC-721 behaviour, verified on BSC 2026-11-23), so the
    ///      zero address is short-circuited here instead of propagating a revert.
    function hasAgentID(address wallet) public view returns (bool) {
        if (wallet == address(0)) return false;
        return agentID.balanceOf(wallet) > 0;
    }

    /// @notice True if `wallet` has an active ERC-8004 binding.
    function isRegistered(address wallet) external view returns (bool) {
        return _bindings[wallet].active;
    }

    function bindingOf(address wallet)
        external
        view
        returns (uint256 erc8004AgentId, uint64 boundAt, bool active)
    {
        AgentBinding storage b = _bindings[wallet];
        return (b.erc8004AgentId, b.boundAt, b.active);
    }

    function walletOfAgent(uint256 erc8004AgentId) external view returns (address) {
        return _agentWallet[erc8004AgentId];
    }

    function capabilityOf(uint256 capabilityId)
        external
        view
        returns (address grantor, address delegate, bytes32 scope, uint64 expiresAt, bool revoked, uint256 parentId)
    {
        Capability storage c = _capabilities[capabilityId];
        if (c.grantor == address(0)) revert UnknownCapability();
        return (c.grantor, c.delegate, c.scope, c.expiresAt, c.revoked, c.parentId);
    }

    /// @notice Founding seat of a wallet (1..44), or 0 if not founding.
    function foundingSeatOf(address wallet) external view returns (uint256) {
        return _foundingSeat[wallet];
    }

    function isFounding(address wallet) external view returns (bool) {
        return _foundingSeat[wallet] != 0;
    }

    function foundingCount() external view returns (uint256) {
        return _foundingCount;
    }

    function guardianOf(address operator) external view returns (address) {
        return _guardians[operator];
    }

    function isFrozen(address operator) external view returns (bool) {
        return _bindings[operator].frozen;
    }

    /// @notice Number of distinct Agent ID holder wallets that have registered.
    /// @dev Exposed for hackathon metrics (interacting Agent ID addresses).
    function uniqueAgentIDInteractors() external view returns (uint256) {
        return _uniqueAgentIDInteractors;
    }

    function totalCapabilityGrants() external view returns (uint256) {
        return _totalCapabilityGrants;
    }

    /// @notice Live authorization check for a delegated action.
    /// @dev Fails closed if ANY of these hold: capability unknown/revoked/
    ///      expired, grantor unbound, or grantor no longer holds an Agent ID.
    function isAuthorized(address grantor, address delegate, bytes32 scope, uint256 capabilityId)
        external
        view
        returns (bool)
    {
        Capability storage c = _capabilities[capabilityId];
        if (c.grantor == address(0)) return false;
        if (c.grantor != grantor || c.delegate != delegate || c.scope != scope) return false;
        if (c.revoked) return false;
        if (block.timestamp > c.expiresAt) return false;
        if (!_bindings[grantor].active) return false;
        if (_bindings[grantor].frozen) return false;
        if (!hasAgentID(grantor)) return false;
        // Attenuation chain: a sub-delegation lives and dies with its parent.
        if (c.parentId != 0) {
            Capability storage p = _capabilities[c.parentId];
            if (p.revoked) return false;
            if (block.timestamp > p.expiresAt) return false;
        }
        return true;
    }

    // -------------------------------------------------------------------------
    // Registration — bind an ERC-8004 agent to its operator's Agent ID wallet
    // -------------------------------------------------------------------------
    /// @notice Register as an operator with Agent ID only (no ERC-8004 agent).
    /// @dev This is the low-friction entry path: one transaction by any
    ///      Agent ID holder activates capability granting. The wallet can
    ///      later upgrade to a full ERC-8004 binding via registerAgent.
    ///      Stored with erc8004AgentId = 0 as the operator-only sentinel.
    function registerOperator() external whenNotPaused {
        if (!hasAgentID(msg.sender)) revert NoAgentID();
        if (_bindings[msg.sender].active) revert AlreadyBound();

        _bindings[msg.sender] = AgentBinding({
            erc8004AgentId: 0,
            boundAt: uint64(block.timestamp),
            active: true,
            frozen: false,
            frozenAt: 0
        });

        _countInteractor(msg.sender);

        emit AgentRegistered(msg.sender, 0);
    }

    /// @notice Bind your ERC-8004 agent identity to your wallet.
    /// @dev Caller must (a) currently own the ERC-8004 agent and
    ///      (b) hold an Agent ID. One active binding per wallet and per agent.
    ///      An operator-only registration (registerOperator) is upgraded in
    ///      place instead of reverting.
    function registerAgent(uint256 erc8004AgentId) external whenNotPaused {
        if (erc8004AgentId == 0) revert ZeroAgentId();
        if (!hasAgentID(msg.sender)) revert NoAgentID();
        if (identityRegistry.ownerOf(erc8004AgentId) != msg.sender) revert NotAgentOwner();

        AgentBinding storage existing = _bindings[msg.sender];
        if (existing.active && existing.erc8004AgentId != 0) revert AlreadyBound();
        if (_agentWallet[erc8004AgentId] != address(0)) revert AgentAlreadyBound();

        _bindings[msg.sender] = AgentBinding({
            erc8004AgentId: erc8004AgentId,
            boundAt: uint64(block.timestamp),
            active: true,
            frozen: existing.frozen,
            frozenAt: existing.frozenAt
        });
        _agentWallet[erc8004AgentId] = msg.sender;

        _countInteractor(msg.sender);

        emit AgentRegistered(msg.sender, erc8004AgentId);
    }

    function _countInteractor(address wallet) internal {
        if (!_countedInteractor[wallet]) {
            _countedInteractor[wallet] = true;
            unchecked {
                _uniqueAgentIDInteractors += 1;
            }

            // Founding 44: the first 44 distinct Agent ID operators claim a
            // seat in registration order. First-come, recorded on-chain,
            // never reassigned — unregistering does not free a seat.
            if (_foundingCount < FOUNDING_SEATS) {
                unchecked {
                    _foundingCount += 1;
                }
                _foundingSeat[wallet] = _foundingCount;
                emit FoundingSeatClaimed(wallet, _foundingCount);
            }
        }
    }

    /// @notice Remove your binding. All capabilities you granted immediately
    ///         stop authorizing (isAuthorized requires an active binding).
    function unregisterAgent() external whenNotPaused {
        AgentBinding storage b = _bindings[msg.sender];
        if (!b.active) revert NotBound();

        uint256 agentId_ = b.erc8004AgentId;
        b.active = false;
        delete _agentWallet[agentId_];

        emit AgentUnregistered(msg.sender, agentId_);
    }

    // -------------------------------------------------------------------------
    // Delegated capabilities
    // -------------------------------------------------------------------------
    /// @notice Grant a narrowly scoped, expiring capability to a delegate.
    /// @dev Grantor must have an active binding and still hold an Agent ID.
    ///      This is an explicit transaction by the grantor — nothing here
    ///      moves assets or bypasses the delegate's own user confirmations
    ///      for asset operations in consuming applications.
    /// @param delegate Address receiving the capability (e.g. a sub-agent).
    /// @param scope Opaque scope id, e.g. keccak256("bip4444:alerts:receive").
    /// @param expiresAt Unix timestamp after which the capability is void.
    /// @return capabilityId Id of the granted capability.
    function grantCapability(address delegate, bytes32 scope, uint64 expiresAt)
        external
        whenNotPaused
        returns (uint256 capabilityId)
    {
        if (!_bindings[msg.sender].active) revert NotBound();
        if (_bindings[msg.sender].frozen) revert FrozenError();
        if (!hasAgentID(msg.sender)) revert NoAgentID();
        if (delegate == address(0) || delegate == msg.sender) revert InvalidDelegate();
        if (scope == bytes32(0)) revert ZeroScope();
        if (expiresAt <= block.timestamp) revert InvalidExpiry();

        capabilityId = _nextCapabilityId++;
        _capabilities[capabilityId] = Capability({
            grantor: msg.sender,
            delegate: delegate,
            scope: scope,
            expiresAt: expiresAt,
            revoked: false,
            parentId: 0
        });

        unchecked {
            _totalCapabilityGrants += 1;
        }

        emit CapabilityGranted(capabilityId, msg.sender, delegate, scope, expiresAt);
    }

    /// @notice Revoke a capability you granted. Only the grantor can revoke.
    function revokeCapability(uint256 capabilityId) external whenNotPaused {
        Capability storage c = _capabilities[capabilityId];
        if (c.grantor == address(0)) revert UnknownCapability();
        if (c.grantor != msg.sender) revert NotGrantor();
        if (c.revoked) revert AlreadyRevoked();

        c.revoked = true;
        emit CapabilityRevoked(capabilityId, msg.sender);
    }

    /// @notice Attenuated sub-delegation: a delegate passes its capability
    ///         one level down — same scope, expiry never beyond the parent's.
    /// @dev Rare-by-design constraints: depth is capped at 1 (a sub-delegated
    ///      capability cannot be sub-delegated again), the scope can never
    ///      widen, and the child dies automatically when the parent is
    ///      revoked or expires (checked in isAuthorized). The root grantor
    ///      stays the capability's grantor, so the operator can always see
    ///      and revoke the whole chain.
    function subDelegate(uint256 parentId, address subDelegate_, uint64 expiresAt)
        external
        whenNotPaused
        returns (uint256 capabilityId)
    {
        Capability storage p = _capabilities[parentId];
        if (p.grantor == address(0)) revert UnknownCapability();
        if (p.parentId != 0) revert CannotSubDelegate();
        if (p.delegate != msg.sender) revert NotDelegate();
        if (p.revoked) revert AlreadyRevoked();
        if (_bindings[p.grantor].frozen) revert FrozenError();
        if (subDelegate_ == address(0) || subDelegate_ == msg.sender || subDelegate_ == p.grantor) {
            revert InvalidDelegate();
        }
        if (expiresAt <= block.timestamp) revert InvalidExpiry();
        if (expiresAt > p.expiresAt) revert ExpiryExceedsParent();

        capabilityId = _nextCapabilityId++;
        _capabilities[capabilityId] = Capability({
            grantor: p.grantor,
            delegate: subDelegate_,
            scope: p.scope,
            expiresAt: expiresAt,
            revoked: false,
            parentId: parentId
        });

        unchecked {
            _totalCapabilityGrants += 1;
        }

        emit CapabilityGranted(capabilityId, p.grantor, subDelegate_, p.scope, expiresAt);
        emit CapabilitySubDelegated(capabilityId, parentId, msg.sender, subDelegate_);
    }

    // -------------------------------------------------------------------------
    // Incident response — panic freeze & guardian rescue
    // -------------------------------------------------------------------------
    /// @notice Set (or clear, with address(0)) the guardian allowed to freeze
    ///         your operator wallet in an emergency. The guardian can ONLY
    ///         freeze — never unfreeze, grant, revoke, or move anything.
    function setGuardian(address guardian) external whenNotPaused {
        if (!_bindings[msg.sender].active) revert NotBound();
        if (guardian == msg.sender) revert InvalidDelegate();
        _guardians[msg.sender] = guardian;
        emit GuardianSet(msg.sender, guardian);
    }

    /// @notice Panic freeze: immediately kills every authorization from your
    ///         wallet (isAuthorized fails) and blocks new grants. Use when a
    ///         key or a sub-agent is compromised. Revocation stays available
    ///         while frozen so you can clean up during the incident.
    function freeze() external whenNotPaused {
        _freeze(msg.sender, msg.sender);
    }

    /// @notice Guardian-triggered freeze for an operator who lost their key.
    function guardianFreeze(address operator) external whenNotPaused {
        if (_guardians[operator] == address(0) || _guardians[operator] != msg.sender) revert NotGuardian();
        _freeze(operator, msg.sender);
    }

    function _freeze(address operator, address by) internal {
        AgentBinding storage b = _bindings[operator];
        if (!b.active) revert NotBound();
        if (b.frozen) revert FrozenError();
        b.frozen = true;
        b.frozenAt = uint64(block.timestamp);
        emit Frozen(operator, by);
    }

    /// @notice Unfreeze your own wallet after FREEZE_COOLDOWN (24h) has
    ///         passed since the freeze. The cooldown stops a thief holding
    ///         a stolen key from instantly undoing a guardian's rescue
    ///         freeze. Only the operator can unfreeze — not the guardian,
    ///         not the contract owner.
    function unfreeze() external whenNotPaused {
        AgentBinding storage b = _bindings[msg.sender];
        if (!b.active) revert NotBound();
        if (!b.frozen) revert NotFrozenError();
        if (block.timestamp < uint256(b.frozenAt) + FREEZE_COOLDOWN) revert FreezeCooldownActive();
        b.frozen = false;
        b.frozenAt = 0;
        emit Unfrozen(msg.sender);
    }

    // -------------------------------------------------------------------------
    // Admin — disclosed, minimal: pause / unpause / ownership only
    // -------------------------------------------------------------------------
    function pause() external onlyOwner {
        if (paused) revert PausedError();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert NotPausedError();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }
}
