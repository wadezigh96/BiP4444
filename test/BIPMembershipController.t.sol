// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BIPMembershipController} from "../contracts/src/BIPMembershipController.sol";
import {MockERC8004Identity} from "./mocks/MockERC8004Identity.sol";

contract BIPMembershipControllerTest is Test {
    BIPMembershipController internal controller;
    MockERC8004Identity internal identity;

    address internal admin = address(0xA11CE);
    address internal alice = address(0xA11CE1);
    address internal bob = address(0xB0B);
    address internal charlie = address(0xC0);

    uint256 internal constant AGENT_ALICE = 1001;
    uint256 internal constant AGENT_BOB = 1002;
    uint256 internal constant AGENT_CHARLIE = 1003;

    event MembershipRegistered(uint256 indexed agentId, uint256 indexed membershipId, address indexed registrant);
    event MembershipRevoked(uint256 indexed agentId, uint256 indexed membershipId, address indexed by);
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        identity = new MockERC8004Identity();

        vm.prank(admin);
        controller = new BIPMembershipController(address(identity));

        // Register mock agents
        identity.setOwner(AGENT_ALICE, alice);
        identity.setOwner(AGENT_BOB, bob);
        identity.setOwner(AGENT_CHARLIE, charlie);
    }

    // -------------------------------------------------------------------------
    // Constructor / views
    // -------------------------------------------------------------------------

    function test_MaxMembersIs4444() public view {
        assertEq(controller.MAX_MEMBERS(), 4444);
    }

    function test_ConstructorSetsOwnerAndRegistry() public view {
        assertEq(controller.owner(), admin);
        assertEq(address(controller.identityRegistry()), address(identity));
        assertEq(controller.activeMemberCount(), 0);
    }

    function test_ConstructorRevertsOnZeroRegistry() public {
        vm.expectRevert(BIPMembershipController.ZeroAddress.selector);
        new BIPMembershipController(address(0));
    }

    // -------------------------------------------------------------------------
    // Registration — happy path
    // -------------------------------------------------------------------------

    function test_Register_Success() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit MembershipRegistered(AGENT_ALICE, 1, alice);
        controller.register(AGENT_ALICE);

        assertTrue(controller.isMember(AGENT_ALICE));
        assertEq(controller.activeMemberCount(), 1);

        (uint256 membershipId, address registeredBy, uint64 registeredAt, bool active) =
            controller.membershipOf(AGENT_ALICE);
        assertEq(membershipId, 1);
        assertEq(registeredBy, alice);
        assertTrue(active);
        assertGt(registeredAt, 0);
    }

    function test_Register_MultipleDistinctAgents() public {
        vm.prank(alice);
        controller.register(AGENT_ALICE);
        vm.prank(bob);
        controller.register(AGENT_BOB);

        assertTrue(controller.isMember(AGENT_ALICE));
        assertTrue(controller.isMember(AGENT_BOB));
        assertEq(controller.activeMemberCount(), 2);

        (uint256 idAlice,,,) = controller.membershipOf(AGENT_ALICE);
        (uint256 idBob,,,) = controller.membershipOf(AGENT_BOB);
        assertEq(idAlice, 1);
        assertEq(idBob, 2);
    }

    // -------------------------------------------------------------------------
    // Registration — negative cases
    // -------------------------------------------------------------------------

    function test_Register_RevertsOnZeroAgentId() public {
        vm.prank(alice);
        vm.expectRevert(BIPMembershipController.ZeroAgentId.selector);
        controller.register(0);
    }

    function test_Register_RevertsWhenNotAgentOwner() public {
        // bob tries to register alice's agent
        vm.prank(bob);
        vm.expectRevert(BIPMembershipController.NotAgentOwner.selector);
        controller.register(AGENT_ALICE);
    }

    function test_Register_RevertsOnDuplicate() public {
        vm.prank(alice);
        controller.register(AGENT_ALICE);

        vm.prank(alice);
        vm.expectRevert(BIPMembershipController.AlreadyMember.selector);
        controller.register(AGENT_ALICE);
    }

    function test_Register_RevertsWhenPaused() public {
        vm.prank(admin);
        controller.pause();

        vm.prank(alice);
        vm.expectRevert(BIPMembershipController.PausedError.selector);
        controller.register(AGENT_ALICE);
    }

    function test_Register_RevertsWhenAgentDoesNotExist() public {
        // agentId 9999 never set on mock → ownerOf reverts
        vm.prank(alice);
        vm.expectRevert(MockERC8004Identity.NonexistentAgent.selector);
        controller.register(9999);
    }

    // -------------------------------------------------------------------------
    // Cap enforcement (4,444)
    // -------------------------------------------------------------------------

    /// @dev Fills the registry to exactly MAX_MEMBERS using sequential agentIds.
    ///      Uses a single owner for speed; still exercises the on-chain counter.
    function test_Cap_ReachedAt4444() public {
        uint256 max = controller.MAX_MEMBERS();
        assertEq(max, 4444);

        // Use a dedicated owner for bulk registration
        address filler = address(0xF111E);

        for (uint256 i = 1; i <= max; i++) {
            identity.setOwner(i, filler);
            vm.prank(filler);
            controller.register(i);
        }

        assertEq(controller.activeMemberCount(), max);

        // 4445th must fail
        uint256 overflowId = max + 1;
        identity.setOwner(overflowId, filler);
        vm.prank(filler);
        vm.expectRevert(BIPMembershipController.CapReached.selector);
        controller.register(overflowId);
    }

    function test_Cap_RevokeFreesSlot() public {
        // Register one, revoke, register again with different agent under same owner path
        vm.prank(alice);
        controller.register(AGENT_ALICE);
        assertEq(controller.activeMemberCount(), 1);

        vm.prank(admin);
        controller.revoke(AGENT_ALICE);
        assertEq(controller.activeMemberCount(), 0);
        assertFalse(controller.isMember(AGENT_ALICE));

        // Same agent can re-register after revoke (current skeleton behaviour)
        vm.prank(alice);
        controller.register(AGENT_ALICE);
        assertTrue(controller.isMember(AGENT_ALICE));
        assertEq(controller.activeMemberCount(), 1);

        (uint256 membershipId,,,) = controller.membershipOf(AGENT_ALICE);
        // membershipId advances (2), even though agent was re-registered
        assertEq(membershipId, 2);
    }

    // -------------------------------------------------------------------------
    // Revoke
    // -------------------------------------------------------------------------

    function test_Revoke_OnlyOwner() public {
        vm.prank(alice);
        controller.register(AGENT_ALICE);

        vm.prank(alice);
        vm.expectRevert(BIPMembershipController.NotOwner.selector);
        controller.revoke(AGENT_ALICE);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit MembershipRevoked(AGENT_ALICE, 1, admin);
        controller.revoke(AGENT_ALICE);

        assertFalse(controller.isMember(AGENT_ALICE));
        assertEq(controller.activeMemberCount(), 0);
    }

    function test_Revoke_RevertsIfNotMember() public {
        vm.prank(admin);
        vm.expectRevert(BIPMembershipController.NotMember.selector);
        controller.revoke(AGENT_ALICE);
    }

    function test_Revoke_RevertsWhenPaused() public {
        vm.prank(alice);
        controller.register(AGENT_ALICE);

        vm.prank(admin);
        controller.pause();

        vm.prank(admin);
        vm.expectRevert(BIPMembershipController.PausedError.selector);
        controller.revoke(AGENT_ALICE);
    }

    // -------------------------------------------------------------------------
    // Pause / unpause
    // -------------------------------------------------------------------------

    function test_Pause_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(BIPMembershipController.NotOwner.selector);
        controller.pause();

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit Paused(admin);
        controller.pause();
        assertTrue(controller.paused());
    }

    function test_Unpause_OnlyOwner() public {
        vm.prank(admin);
        controller.pause();

        vm.prank(alice);
        vm.expectRevert(BIPMembershipController.NotOwner.selector);
        controller.unpause();

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit Unpaused(admin);
        controller.unpause();
        assertFalse(controller.paused());
    }

    function test_Pause_RevertsIfAlreadyPaused() public {
        vm.prank(admin);
        controller.pause();

        vm.prank(admin);
        vm.expectRevert(BIPMembershipController.PausedError.selector);
        controller.pause();
    }

    function test_Unpause_RevertsIfNotPaused() public {
        vm.prank(admin);
        vm.expectRevert(BIPMembershipController.NotPausedError.selector);
        controller.unpause();
    }

    // -------------------------------------------------------------------------
    // Ownership transfer (admin)
    // -------------------------------------------------------------------------

    function test_TransferOwnership() public {
        address newAdmin = address(0xDEAD);
        vm.prank(admin);
        controller.transferOwnership(newAdmin);
        assertEq(controller.owner(), newAdmin);

        // old admin can no longer pause
        vm.prank(admin);
        vm.expectRevert(BIPMembershipController.NotOwner.selector);
        controller.pause();

        // new admin can
        vm.prank(newAdmin);
        controller.pause();
        assertTrue(controller.paused());
    }

    function test_TransferOwnership_RevertsOnZero() public {
        vm.prank(admin);
        vm.expectRevert(BIPMembershipController.ZeroAddress.selector);
        controller.transferOwnership(address(0));
    }

    // -------------------------------------------------------------------------
    // Fuzz: register only when caller is agent owner
    // -------------------------------------------------------------------------

    function testFuzz_Register_OnlyAgentOwner(address caller, uint256 agentId) public {
        vm.assume(caller != address(0));
        vm.assume(agentId != 0);
        // Avoid collision with agents already set in setUp if caller differs
        identity.setOwner(agentId, alice);

        if (caller == alice) {
            vm.prank(caller);
            controller.register(agentId);
            assertTrue(controller.isMember(agentId));
        } else {
            vm.prank(caller);
            vm.expectRevert(BIPMembershipController.NotAgentOwner.selector);
            controller.register(agentId);
        }
    }
}
