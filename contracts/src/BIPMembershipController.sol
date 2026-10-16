// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBIPMembershipController} from "../interfaces/IBIPMembershipController.sol";
import {IERC8004Identity} from "../interfaces/IERC8004Identity.sol";

/// @title BIPMembershipController
/// @notice Membership registry referencing existing ERC-8004 identities.
/// @dev Pre-audit implementation. Never deploy to mainnet until all release gates pass.
contract BIPMembershipController is IBIPMembershipController {
    uint256 private constant _MAX_MEMBERS = 4444;
    uint256 public constant MAX_AUTHORIZATION_LIFETIME = 1 days;
    uint256 private constant _SECP256K1N_HALF =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    bytes32 private constant _DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _AUTHORIZATION_TYPEHASH = keccak256(
        "MembershipAuthorization(uint256 agentId,bytes32 paymentIdHash,bytes32 roleHash,uint256 nonce,uint256 deadline)"
    );
    bytes32 private constant _NAME_HASH = keccak256("BIP4444 Membership Controller");
    bytes32 private constant _VERSION_HASH = keccak256("1");

    IERC8004Identity public immutable identityRegistry;

    struct Membership {
        uint256 membershipId;
        address registeredBy;
        uint64 registeredAt;
        bool active;
    }

    mapping(uint256 => Membership) private _memberships;
    mapping(address => bool) public isRelayer;
    mapping(address => uint256) public ownerNonces;
    mapping(bytes32 => bool) public usedPaymentIds;

    uint256 private _nextMembershipId = 1;
    uint256 private _activeMemberCount;

    address public owner;
    address public pendingOwner;
    bool public paused;

    error NotOwner();
    error NotPendingOwner();
    error NotRelayer();
    error PausedError();
    error NotPausedError();
    error CapReached();
    error AlreadyMember();
    error NotMember();
    error ZeroAddress();
    error ZeroAgentId();
    error InvalidSignature();
    error InvalidAuthorization();
    error SignatureExpired();
    error SignatureLifetimeTooLong();
    error PaymentIdAlreadyUsed();

    event OwnershipTransferStarted(address indexed owner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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
        emit OwnershipTransferred(address(0), msg.sender);
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

    /// @notice Relayer registration with owner consent bound to this chain, contract, payment and role.
    /// @dev The backend must call only after B402 settlement is confirmed. The contract cannot verify
    ///      off-chain payment; owner signature prevents the relayer from silently enrolling an agent.
    function registerFor(
        uint256 agentId,
        bytes32 paymentIdHash,
        bytes32 roleHash,
        uint256 deadline,
        bytes calldata ownerSignature
    ) external override onlyRelayer whenNotPaused {
        if (agentId == 0) revert ZeroAgentId();
        if (paymentIdHash == bytes32(0) || roleHash == bytes32(0)) revert InvalidAuthorization();
        if (deadline < block.timestamp) revert SignatureExpired();
        if (deadline > block.timestamp + MAX_AUTHORIZATION_LIFETIME) revert SignatureLifetimeTooLong();
        if (usedPaymentIds[paymentIdHash]) revert PaymentIdAlreadyUsed();

        address agentOwner = identityRegistry.ownerOf(agentId);
        uint256 nonce = ownerNonces[agentOwner];
        bytes32 digest = authorizationDigest(agentId, paymentIdHash, roleHash, nonce, deadline);
        if (_recoverSigner(digest, ownerSignature) != agentOwner) revert InvalidSignature();

        // Checks-effects-interactions: no external calls follow these state changes except registry
        // ownership lookup above. Reverts in _register roll all changes back.
        ownerNonces[agentOwner] = nonce + 1;
        usedPaymentIds[paymentIdHash] = true;
        _register(agentId, agentOwner, msg.sender);
    }

    /// @notice EIP-712 digest helper for clients signing the relayer authorization.
    function authorizationDigest(
        uint256 agentId,
        bytes32 paymentIdHash,
        bytes32 roleHash,
        uint256 nonce,
        uint256 deadline
    ) public view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(_DOMAIN_TYPEHASH, _NAME_HASH, _VERSION_HASH, block.chainid, address(this))
        );
        bytes32 structHash = keccak256(
            abi.encode(_AUTHORIZATION_TYPEHASH, agentId, paymentIdHash, roleHash, nonce, deadline)
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function _recoverSigner(bytes32 digest, bytes calldata signature) internal pure returns (address signer) {
        if (signature.length != 65) revert InvalidSignature();

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        if (uint256(s) > _SECP256K1N_HALF || (v != 27 && v != 28)) revert InvalidSignature();
        signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
    }

    function _register(uint256 agentId, address agentOwner, address operator) internal {
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
        emit MembershipRegistered(agentId, newId, operator);
    }

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

    /// @notice Starts a two-step ownership transfer. The pending owner must accept explicitly.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner || msg.sender == address(0)) revert NotPendingOwner();
        address previousOwner = owner;
        owner = msg.sender;
        pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, msg.sender);
    }
}
