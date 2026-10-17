// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BIPMembershipController} from "../contracts/src/BIPMembershipController.sol";
import {MockERC8004Identity} from "./mocks/MockERC8004Identity.sol";

contract BIPMembershipControllerTest is Test {
    BIPMembershipController internal controller;
    MockERC8004Identity internal identity;

    address internal admin = address(0xA11CE);
    address internal alice;
    address internal bob;
    address internal charlie;
    address internal relayer = address(0xB402);

    uint256 internal constant ALICE_PK = 0xA11CE1;
    uint256 internal constant BOB_PK = 0xB0B;
    uint256 internal constant CHARLIE_PK = 0xC0;
    uint256 internal constant FILLER_PK = 0xF111E;
    uint256 internal constant AGENT_ALICE = 1001;
    uint256 internal constant AGENT_BOB = 1002;
    uint256 internal constant AGENT_CHARLIE = 1003;
    bytes32 internal constant ROLE_HASH = keccak256("test-role");

    event MembershipRegistered(uint256 indexed agentId, uint256 indexed membershipId, address indexed registrant, address identityOwner, bytes32 paymentIdHash, bytes32 roleHash);
    event MembershipRevoked(uint256 indexed agentId, uint256 indexed membershipId, address indexed by);
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        alice = vm.addr(ALICE_PK);
        bob = vm.addr(BOB_PK);
        charlie = vm.addr(CHARLIE_PK);

        identity = new MockERC8004Identity();
        vm.prank(admin);
        controller = new BIPMembershipController(address(identity));

        identity.setOwner(AGENT_ALICE, alice);
        identity.setOwner(AGENT_BOB, bob);
        identity.setOwner(AGENT_CHARLIE, charlie);

        vm.prank(admin);
        controller.setRelayer(relayer, true);
    }

    function _signature(
        uint256 agentId,
        uint256 signingKey,
        address expectedOwner,
        bytes32 paymentHash,
        bytes32 roleHash,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 digest = controller.authorizationDigest(
            agentId, paymentHash, roleHash, controller.ownerNonces(expectedOwner), deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _registerAgent(uint256 agentId, uint256 ownerKey, bytes32 paymentHash) internal {
        address agentOwner = vm.addr(ownerKey);
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _signature(
            agentId, ownerKey, agentOwner, paymentHash, ROLE_HASH, deadline
        );
        vm.prank(relayer);
        controller.registerFor(agentId, paymentHash, ROLE_HASH, deadline, signature);
    }

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

    function test_FreeRegisterSelectorIsNotAvailable() public {
        (bool success,) = address(controller).call(abi.encodeWithSignature("register(uint256)", AGENT_ALICE));
        assertFalse(success);
        assertFalse(controller.isMember(AGENT_ALICE));
    }

    function test_RegisterFor_Success() public {
        bytes32 paymentHash = keccak256("alice-payment-1");
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _signature(
            AGENT_ALICE, ALICE_PK, alice, paymentHash, ROLE_HASH, deadline
        );

        vm.prank(relayer);
        vm.expectEmit(true, true, true, true);
        emit MembershipRegistered(AGENT_ALICE, 1, relayer, alice, keccak256("alice-payment-1"), ROLE_HASH);
        controller.registerFor(AGENT_ALICE, paymentHash, ROLE_HASH, deadline, signature);

        assertTrue(controller.isMember(AGENT_ALICE));
        assertEq(controller.activeMemberCount(), 1);
        assertTrue(controller.usedPaymentIds(paymentHash));
        assertEq(controller.ownerNonces(alice), 1);

        (uint256 membershipId, address registeredBy, uint64 registeredAt, bool active) =
            controller.membershipOf(AGENT_ALICE);
        assertEq(membershipId, 1);
        assertEq(registeredBy, alice);
        assertTrue(active);
        assertGt(registeredAt, 0);
    }

    function test_RegisterFor_MultipleDistinctAgents() public {
        _registerAgent(AGENT_ALICE, ALICE_PK, keccak256("alice-payment"));
        _registerAgent(AGENT_BOB, BOB_PK, keccak256("bob-payment"));

        assertTrue(controller.isMember(AGENT_ALICE));
        assertTrue(controller.isMember(AGENT_BOB));
        assertEq(controller.activeMemberCount(), 2);

        (uint256 idAlice,,,) = controller.membershipOf(AGENT_ALICE);
        (uint256 idBob,,,) = controller.membershipOf(AGENT_BOB);
        assertEq(idAlice, 1);
        assertEq(idBob, 2);
    }

    function test_RegisterFor_RevertsOnZeroAgentId() public {
        bytes32 paymentHash = keccak256("zero-agent");
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _signature(0, ALICE_PK, alice, paymentHash, ROLE_HASH, deadline);
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.ZeroAgentId.selector);
        controller.registerFor(0, paymentHash, ROLE_HASH, deadline, signature);
    }

    function test_RegisterFor_RevertsWhenSignatureIsNotFromIdentityOwner() public {
        bytes32 paymentHash = keccak256("wrong-signer");
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _signature(
            AGENT_ALICE, BOB_PK, alice, paymentHash, ROLE_HASH, deadline
        );
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.InvalidSignature.selector);
        controller.registerFor(AGENT_ALICE, paymentHash, ROLE_HASH, deadline, signature);
    }

    function test_RegisterFor_RevertsOnDuplicateActiveMembership() public {
        _registerAgent(AGENT_ALICE, ALICE_PK, keccak256("alice-first-payment"));
        bytes32 anotherPayment = keccak256("alice-second-payment");
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _signature(
            AGENT_ALICE, ALICE_PK, alice, anotherPayment, ROLE_HASH, deadline
        );
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.AlreadyMember.selector);
        controller.registerFor(AGENT_ALICE, anotherPayment, ROLE_HASH, deadline, signature);
    }

    function test_RegisterFor_RevertsWhenPaused() public {
        vm.prank(admin);
        controller.pause();

        bytes32 paymentHash = keccak256("paused-payment");
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _signature(
            AGENT_ALICE, ALICE_PK, alice, paymentHash, ROLE_HASH, deadline
        );
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.PausedError.selector);
        controller.registerFor(AGENT_ALICE, paymentHash, ROLE_HASH, deadline, signature);
    }

    function test_RegisterFor_RevertsWhenAgentDoesNotExist() public {
        bytes32 paymentHash = keccak256("missing-agent");
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _signature(9999, ALICE_PK, address(0), paymentHash, ROLE_HASH, deadline);
        vm.prank(relayer);
        vm.expectRevert(MockERC8004Identity.NonexistentAgent.selector);
        controller.registerFor(9999, paymentHash, ROLE_HASH, deadline, signature);
    }

    function test_Cap_ReachedAt4444() public {
        uint256 max = controller.MAX_MEMBERS();
        address filler = vm.addr(FILLER_PK);

        for (uint256 i = 1; i <= max; i++) {
            identity.setOwner(i, filler);
            _registerAgent(i, FILLER_PK, keccak256(abi.encode("cap-payment", i)));
        }

        assertEq(controller.activeMemberCount(), max);

        uint256 overflowId = max + 1;
        identity.setOwner(overflowId, filler);
        bytes32 paymentHash = keccak256("cap-overflow-payment");
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _signature(
            overflowId, FILLER_PK, filler, paymentHash, ROLE_HASH, deadline
        );
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.CapReached.selector);
        controller.registerFor(overflowId, paymentHash, ROLE_HASH, deadline, signature);
    }

    function test_Cap_RevokeFreesSlot() public {
        _registerAgent(AGENT_ALICE, ALICE_PK, keccak256("revoke-first-payment"));
        assertEq(controller.activeMemberCount(), 1);

        vm.prank(admin);
        controller.revoke(AGENT_ALICE);
        assertEq(controller.activeMemberCount(), 0);
        assertFalse(controller.isMember(AGENT_ALICE));

        _registerAgent(AGENT_ALICE, ALICE_PK, keccak256("revoke-second-payment"));
        assertTrue(controller.isMember(AGENT_ALICE));
        assertEq(controller.activeMemberCount(), 1);
        (uint256 membershipId,,,) = controller.membershipOf(AGENT_ALICE);
        assertEq(membershipId, 2);
    }

    function test_RevokeSelf_OnlyCurrentIdentityOwnerCanRevoke() public {
        bytes32 paymentHash = keccak256("self-revoke-payment");
        _registerAgent(AGENT_ALICE, ALICE_PK, paymentHash);

        vm.prank(charlie);
        vm.expectRevert(BIPMembershipController.NotAgentOwner.selector);
        controller.revokeSelf(AGENT_ALICE);

        // Ownership follows the ERC-8004 agentId, so the new owner can revoke.
        identity.setOwner(AGENT_ALICE, bob);
        assertTrue(controller.isMember(AGENT_ALICE));

        vm.prank(alice);
        vm.expectRevert(BIPMembershipController.NotAgentOwner.selector);
        controller.revokeSelf(AGENT_ALICE);

        vm.prank(bob);
        controller.revokeSelf(AGENT_ALICE);
        assertFalse(controller.isMember(AGENT_ALICE));
        assertEq(controller.activeMemberCount(), 0);
    }

    function test_RevokeSelf_IsAllowedWhilePaused() public {
        _registerAgent(AGENT_ALICE, ALICE_PK, keccak256("self-revoke-paused"));
        vm.prank(admin);
        controller.pause();

        vm.prank(alice);
        controller.revokeSelf(AGENT_ALICE);
        assertFalse(controller.isMember(AGENT_ALICE));
        assertEq(controller.activeMemberCount(), 0);
        assertTrue(controller.paused());
    }

    function test_AdminRevoke_IsAllowedWhilePaused() public {
        _registerAgent(AGENT_ALICE, ALICE_PK, keccak256("admin-revoke-paused"));
        vm.prank(admin);
        controller.pause();

        vm.prank(admin);
        controller.revoke(AGENT_ALICE);
        assertFalse(controller.isMember(AGENT_ALICE));
        assertEq(controller.activeMemberCount(), 0);
        assertTrue(controller.paused());
    }

    function test_ReactivationRequiresFreshPaymentAndGetsNewMembershipId() public {
        _registerAgent(AGENT_ALICE, ALICE_PK, keccak256("reactivation-payment-1"));
        (uint256 firstId,,,) = controller.membershipOf(AGENT_ALICE);
        assertEq(firstId, 1);

        vm.prank(admin);
        controller.revoke(AGENT_ALICE);

        _registerAgent(AGENT_ALICE, ALICE_PK, keccak256("reactivation-payment-2"));
        (uint256 secondId,,, bool active) = controller.membershipOf(AGENT_ALICE);
        assertEq(secondId, 2);
        assertTrue(active);
        assertEq(controller.activeMemberCount(), 1);
    }

    function test_Revoke_OnlyOwner() public {
        _registerAgent(AGENT_ALICE, ALICE_PK, keccak256("revoke-owner-payment"));
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
        _registerAgent(AGENT_ALICE, ALICE_PK, keccak256("revoke-paused-payment"));
        vm.prank(admin);
        controller.pause();
        vm.prank(admin);
        vm.expectRevert(BIPMembershipController.PausedError.selector);
        controller.revoke(AGENT_ALICE);
    }

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

    function test_TransferOwnership_RequiresAcceptance() public {
        address newAdmin = address(0xDEAD);
        vm.prank(admin);
        controller.transferOwnership(newAdmin);
        assertEq(controller.owner(), admin);
        assertEq(controller.pendingOwner(), newAdmin);

        vm.prank(newAdmin);
        controller.acceptOwnership();
        assertEq(controller.owner(), newAdmin);
        assertEq(controller.pendingOwner(), address(0));

        vm.prank(admin);
        vm.expectRevert(BIPMembershipController.NotOwner.selector);
        controller.pause();
        vm.prank(newAdmin);
        controller.pause();
        assertTrue(controller.paused());
    }

    function test_AcceptOwnership_RevertsForNonPendingOwner() public {
        vm.prank(admin);
        controller.transferOwnership(address(0xDEAD));
        vm.prank(alice);
        vm.expectRevert(BIPMembershipController.NotPendingOwner.selector);
        controller.acceptOwnership();
    }

    function test_TransferOwnership_RevertsOnZero() public {
        vm.prank(admin);
        vm.expectRevert(BIPMembershipController.ZeroAddress.selector);
        controller.transferOwnership(address(0));
    }

    function testFuzz_RegisterForRejectsSignatureFromWrongOwner(uint256 wrongKey, uint256 agentId) public {
        vm.assume(wrongKey > 0);
        vm.assume(wrongKey < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);
        vm.assume(wrongKey != ALICE_PK);
        vm.assume(agentId != 0);

        identity.setOwner(agentId, alice);
        bytes32 paymentHash = keccak256(abi.encode("fuzz-payment", agentId));
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _signature(
            agentId, wrongKey, alice, paymentHash, ROLE_HASH, deadline
        );
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.InvalidSignature.selector);
        controller.registerFor(agentId, paymentHash, ROLE_HASH, deadline, signature);
    }
}
