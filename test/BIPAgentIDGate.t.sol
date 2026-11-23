// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BIPAgentIDGate} from "../contracts/src/BIPAgentIDGate.sol";
import {MockAgentID} from "./mocks/MockAgentID.sol";
import {MockERC8004Identity} from "./mocks/MockERC8004Identity.sol";

contract BIPAgentIDGateTest is Test {
    BIPAgentIDGate internal gate;
    MockAgentID internal agentID;
    MockERC8004Identity internal identity;

    address internal admin = address(0xA11CE);
    address internal alice = address(0xA11CE1);
    address internal bob = address(0xB0B);
    address internal subAgent = address(0x5AB);
    address internal stranger = address(0x577);

    uint256 internal constant AGENT_ALICE = 1001;
    uint256 internal constant AGENT_BOB = 1002;

    bytes32 internal constant SCOPE_ALERTS = keccak256("bip4444:alerts:receive");
    bytes32 internal constant SCOPE_OTHER = keccak256("bip4444:other");

    event AgentRegistered(address indexed wallet, uint256 indexed erc8004AgentId);
    event AgentUnregistered(address indexed wallet, uint256 indexed erc8004AgentId);
    event CapabilityGranted(
        uint256 indexed capabilityId, address indexed grantor, address indexed delegate, bytes32 scope, uint64 expiresAt
    );
    event CapabilityRevoked(uint256 indexed capabilityId, address indexed grantor);

    function setUp() public {
        agentID = new MockAgentID();
        identity = new MockERC8004Identity();

        vm.prank(admin);
        gate = new BIPAgentIDGate(address(agentID), address(identity));

        identity.setOwner(AGENT_ALICE, alice);
        identity.setOwner(AGENT_BOB, bob);

        // alice and bob hold an Agent ID; stranger does not
        agentID.setBalance(alice, 1);
        agentID.setBalance(bob, 1);
    }

    function _registerAlice() internal {
        vm.prank(alice);
        gate.registerAgent(AGENT_ALICE);
    }

    function _grantFromAlice() internal returns (uint256) {
        vm.prank(alice);
        return gate.grantCapability(subAgent, SCOPE_ALERTS, uint64(block.timestamp + 1 days));
    }

    // -------------------------------------------------------------------------
    // Constructor / views
    // -------------------------------------------------------------------------

    function test_ConstructorSetsConfig() public view {
        assertEq(gate.owner(), admin);
        assertEq(address(gate.agentID()), address(agentID));
        assertEq(address(gate.identityRegistry()), address(identity));
        assertEq(gate.uniqueAgentIDInteractors(), 0);
    }

    function test_ConstructorRevertsOnZero() public {
        vm.expectRevert(BIPAgentIDGate.ZeroAddress.selector);
        new BIPAgentIDGate(address(0), address(identity));
        vm.expectRevert(BIPAgentIDGate.ZeroAddress.selector);
        new BIPAgentIDGate(address(agentID), address(0));
    }

    function test_HasAgentID() public view {
        assertTrue(gate.hasAgentID(alice));
        assertFalse(gate.hasAgentID(stranger));
    }

    // -------------------------------------------------------------------------
    // Registration
    // -------------------------------------------------------------------------

    function test_Register_Success() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit AgentRegistered(alice, AGENT_ALICE);
        gate.registerAgent(AGENT_ALICE);

        assertTrue(gate.isRegistered(alice));
        assertEq(gate.walletOfAgent(AGENT_ALICE), alice);
        assertEq(gate.uniqueAgentIDInteractors(), 1);

        (uint256 boundId,, bool active) = gate.bindingOf(alice);
        assertEq(boundId, AGENT_ALICE);
        assertTrue(active);
    }

    function test_Register_RevertsWithoutAgentID() public {
        // bob owns AGENT_BOB but simulate him losing / never claiming Agent ID
        agentID.setBalance(bob, 0);
        vm.prank(bob);
        vm.expectRevert(BIPAgentIDGate.NoAgentID.selector);
        gate.registerAgent(AGENT_BOB);
    }

    function test_Register_RevertsWhenNotAgentOwner() public {
        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.NotAgentOwner.selector);
        gate.registerAgent(AGENT_BOB);
    }

    function test_Register_RevertsOnZeroAgentId() public {
        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.ZeroAgentId.selector);
        gate.registerAgent(0);
    }

    function test_Register_RevertsOnDuplicateBinding() public {
        _registerAlice();
        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.AlreadyBound.selector);
        gate.registerAgent(AGENT_ALICE);
    }

    function test_Register_RevertsWhenAgentBoundToOtherWallet() public {
        _registerAlice();
        // alice's agent cannot be bound again by bob even though bob has Agent ID
        identity.setOwner(AGENT_ALICE, bob); // ownership moved, binding persists
        vm.prank(bob);
        vm.expectRevert(BIPAgentIDGate.AgentAlreadyBound.selector);
        gate.registerAgent(AGENT_ALICE);
    }

    function test_UniqueInteractors_CountsWalletOnce() public {
        _registerAlice();
        vm.prank(alice);
        gate.unregisterAgent();
        _registerAlice();
        assertEq(gate.uniqueAgentIDInteractors(), 1);

        vm.prank(bob);
        gate.registerAgent(AGENT_BOB);
        assertEq(gate.uniqueAgentIDInteractors(), 2);
    }

    // -------------------------------------------------------------------------
    // Unregister
    // -------------------------------------------------------------------------

    function test_Unregister_Success() public {
        _registerAlice();
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit AgentUnregistered(alice, AGENT_ALICE);
        gate.unregisterAgent();

        assertFalse(gate.isRegistered(alice));
        assertEq(gate.walletOfAgent(AGENT_ALICE), address(0));
    }

    function test_Unregister_RevertsWhenNotBound() public {
        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.NotBound.selector);
        gate.unregisterAgent();
    }

    // -------------------------------------------------------------------------
    // Capabilities
    // -------------------------------------------------------------------------

    function test_Grant_AndIsAuthorized() public {
        _registerAlice();
        uint64 expiry = uint64(block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit CapabilityGranted(1, alice, subAgent, SCOPE_ALERTS, expiry);
        uint256 id = gate.grantCapability(subAgent, SCOPE_ALERTS, expiry);

        assertEq(id, 1);
        assertEq(gate.totalCapabilityGrants(), 1);
        assertTrue(gate.isAuthorized(alice, subAgent, SCOPE_ALERTS, id));
        // wrong scope / wrong delegate fail
        assertFalse(gate.isAuthorized(alice, subAgent, SCOPE_OTHER, id));
        assertFalse(gate.isAuthorized(alice, stranger, SCOPE_ALERTS, id));
        // unknown id fails closed
        assertFalse(gate.isAuthorized(alice, subAgent, SCOPE_ALERTS, 999));
    }

    function test_Grant_RevertsWhenNotBound() public {
        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.NotBound.selector);
        gate.grantCapability(subAgent, SCOPE_ALERTS, uint64(block.timestamp + 1 days));
    }

    function test_Grant_RevertsOnBadParams() public {
        _registerAlice();
        uint64 expiry = uint64(block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.InvalidDelegate.selector);
        gate.grantCapability(address(0), SCOPE_ALERTS, expiry);

        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.InvalidDelegate.selector);
        gate.grantCapability(alice, SCOPE_ALERTS, expiry);

        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.ZeroScope.selector);
        gate.grantCapability(subAgent, bytes32(0), expiry);

        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.InvalidExpiry.selector);
        gate.grantCapability(subAgent, SCOPE_ALERTS, uint64(block.timestamp));
    }

    function test_Revoke_OnlyGrantor_AndFailsClosed() public {
        _registerAlice();
        uint256 id = _grantFromAlice();

        vm.prank(bob);
        vm.expectRevert(BIPAgentIDGate.NotGrantor.selector);
        gate.revokeCapability(id);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit CapabilityRevoked(id, alice);
        gate.revokeCapability(id);

        assertFalse(gate.isAuthorized(alice, subAgent, SCOPE_ALERTS, id));

        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.AlreadyRevoked.selector);
        gate.revokeCapability(id);
    }

    function test_Revoke_UnknownCapability() public {
        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.UnknownCapability.selector);
        gate.revokeCapability(42);
    }

    function test_Authorization_Expires() public {
        _registerAlice();
        uint256 id = _grantFromAlice();
        assertTrue(gate.isAuthorized(alice, subAgent, SCOPE_ALERTS, id));

        vm.warp(block.timestamp + 2 days);
        assertFalse(gate.isAuthorized(alice, subAgent, SCOPE_ALERTS, id));
    }

    function test_Authorization_DiesWhenGrantorLosesAgentID() public {
        _registerAlice();
        uint256 id = _grantFromAlice();
        assertTrue(gate.isAuthorized(alice, subAgent, SCOPE_ALERTS, id));

        // Agent ID is non-transferable on-chain, but model any loss path
        agentID.setBalance(alice, 0);
        assertFalse(gate.isAuthorized(alice, subAgent, SCOPE_ALERTS, id));
    }

    function test_Authorization_DiesOnUnregister() public {
        _registerAlice();
        uint256 id = _grantFromAlice();

        vm.prank(alice);
        gate.unregisterAgent();
        assertFalse(gate.isAuthorized(alice, subAgent, SCOPE_ALERTS, id));
    }

    // -------------------------------------------------------------------------
    // Pause / ownership — owner powers are pause-only, no capability control
    // -------------------------------------------------------------------------

    function test_Pause_BlocksRegisterAndGrant() public {
        vm.prank(admin);
        gate.pause();

        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.PausedError.selector);
        gate.registerAgent(AGENT_ALICE);

        vm.prank(admin);
        gate.unpause();
        _registerAlice();

        vm.prank(admin);
        gate.pause();
        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.PausedError.selector);
        gate.grantCapability(subAgent, SCOPE_ALERTS, uint64(block.timestamp + 1 days));
    }

    function test_OwnerCannotRevokeUserCapability() public {
        _registerAlice();
        uint256 id = _grantFromAlice();

        vm.prank(admin);
        vm.expectRevert(BIPAgentIDGate.NotGrantor.selector);
        gate.revokeCapability(id);
        assertTrue(gate.isAuthorized(alice, subAgent, SCOPE_ALERTS, id));
    }

    function test_Pause_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(BIPAgentIDGate.NotOwner.selector);
        gate.pause();
    }
}
