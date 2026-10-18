// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BIPMembershipController} from "../contracts/src/BIPMembershipController.sol";
import {MockERC8004Identity} from "./mocks/MockERC8004Identity.sol";

/// @dev These tests cover owner-consent signatures, not B402 payment settlement.
contract BIPMembershipRelayerTest is Test {
    BIPMembershipController internal controller;
    MockERC8004Identity internal identity;

    uint256 internal constant ALICE_PK = 0xA11CE;
    address internal alice;
    address internal admin = address(0xA11CE);
    address internal relayer = address(0xB402);
    address internal stranger = address(0xBAD);
    uint256 internal constant AGENT_ID = 1001;
    bytes32 internal constant PAYMENT_HASH = keccak256("payment-1");
    bytes32 internal constant ROLE_HASH = keccak256("research");

    event MembershipRegistered(uint256 indexed agentId, uint256 indexed membershipId, address indexed registrant, address identityOwner, bytes32 paymentIdHash, bytes32 roleHash);

    function setUp() public {
        alice = vm.addr(ALICE_PK);
        identity = new MockERC8004Identity();
        vm.prank(admin);
        controller = new BIPMembershipController(address(identity));
        identity.setOwner(AGENT_ID, alice);
        vm.prank(admin);
        controller.setRelayer(relayer, true);
    }

    function _sign(
        uint256 agentId,
        bytes32 paymentHash,
        bytes32 roleHash,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 digest = controller.authorizationDigest(
            agentId, paymentHash, roleHash, controller.agentNonces(agentId), deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PK, digest);
        return abi.encodePacked(r, s, v);
    }

    function _register(
        uint256 agentId,
        bytes32 paymentHash,
        bytes32 roleHash,
        uint256 deadline
    ) internal {
        bytes memory signature = _sign(agentId, paymentHash, roleHash, deadline);
        vm.prank(relayer);
        controller.registerFor(agentId, paymentHash, roleHash, deadline, signature);
    }

    function test_RelayerCanRegisterWithOwnerConsent() public {
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline);

        vm.prank(relayer);
        vm.expectEmit(true, true, true, true);
        emit MembershipRegistered(AGENT_ID, 1, relayer, alice, PAYMENT_HASH, ROLE_HASH);
        controller.registerFor(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline, signature);

        assertTrue(controller.isMember(AGENT_ID));
        assertEq(controller.activeMemberCount(), 1);
        assertEq(controller.ownerNonces(alice), 1);
        assertTrue(controller.usedPaymentIds(PAYMENT_HASH));
        (uint256 id, address registeredBy,, bool active) = controller.membershipOf(AGENT_ID);
        assertEq(id, 1);
        assertEq(registeredBy, alice);
        assertTrue(active);
    }

    function test_RegisterFor_RevertsForNonRelayer() public {
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline);
        vm.prank(stranger);
        vm.expectRevert(BIPMembershipController.NotRelayer.selector);
        controller.registerFor(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline, signature);
    }

    function test_SetRelayer_OnlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(BIPMembershipController.NotOwner.selector);
        controller.setRelayer(stranger, true);
    }

    function test_SetRelayer_RejectsZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(BIPMembershipController.ZeroAddress.selector);
        controller.setRelayer(address(0), true);
    }

    function test_DisabledRelayerCannotRegister() public {
        vm.prank(admin);
        controller.setRelayer(relayer, false);
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline);
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.NotRelayer.selector);
        controller.registerFor(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline, signature);
    }

    function test_RegisterFor_RevertsWhenPaused() public {
        vm.prank(admin);
        controller.pause();
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline);
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.PausedError.selector);
        controller.registerFor(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline, signature);
    }

    function test_RegisterFor_RevertsOnZeroAgentId() public {
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(0, PAYMENT_HASH, ROLE_HASH, deadline);
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.ZeroAgentId.selector);
        controller.registerFor(0, PAYMENT_HASH, ROLE_HASH, deadline, signature);
    }

    function test_RegisterFor_RevertsOnDuplicateMembership() public {
        uint256 deadline = block.timestamp + 1 days;
        _register(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline);
        bytes32 anotherPayment = keccak256("payment-2");
        bytes memory signature = _sign(AGENT_ID, anotherPayment, ROLE_HASH, deadline);
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.AlreadyMember.selector);
        controller.registerFor(AGENT_ID, anotherPayment, ROLE_HASH, deadline, signature);
    }

    function test_RegisterFor_RevertsWhenAgentDoesNotExist() public {
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(9999, PAYMENT_HASH, ROLE_HASH, deadline);
        vm.prank(relayer);
        vm.expectRevert(MockERC8004Identity.NonexistentAgent.selector);
        controller.registerFor(9999, PAYMENT_HASH, ROLE_HASH, deadline, signature);
    }

    function test_RegisterFor_RejectsExpiredSignature() public {
        uint256 deadline = block.timestamp - 1;
        bytes memory signature = _sign(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline);
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.SignatureExpired.selector);
        controller.registerFor(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline, signature);
    }

    function test_RegisterFor_RejectsSignatureWithExcessiveLifetime() public {
        uint256 deadline = block.timestamp + 2 days;
        bytes memory signature = _sign(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline);
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.SignatureLifetimeTooLong.selector);
        controller.registerFor(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline, signature);
    }

    function test_RegisterFor_BindsSignatureToRole() public {
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline);
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.InvalidSignature.selector);
        controller.registerFor(
            AGENT_ID, PAYMENT_HASH, keccak256("admin"), deadline, signature
        );
    }

    function test_RegisterFor_RejectsReusedPaymentId() public {
        uint256 deadline = block.timestamp + 1 days;
        _register(AGENT_ID, PAYMENT_HASH, ROLE_HASH, deadline);
        // Even after revocation, the same payment identifier can never be consumed again.
        vm.prank(admin);
        controller.revoke(AGENT_ID);

        bytes32 newRole = keccak256("trader");
        bytes memory signature = _sign(AGENT_ID, PAYMENT_HASH, newRole, deadline);
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.PaymentIdAlreadyUsed.selector);
        controller.registerFor(AGENT_ID, PAYMENT_HASH, newRole, deadline, signature);
    }

    function test_RegisterFor_RejectsEmptyAuthorizationFields() public {
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(AGENT_ID, PAYMENT_HASH, bytes32(0), deadline);
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.InvalidAuthorization.selector);
        controller.registerFor(AGENT_ID, PAYMENT_HASH, bytes32(0), deadline, signature);
    }

    function test_RegisterFor_RejectsMalformedSignature() public {
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.InvalidSignature.selector);
        controller.registerFor(AGENT_ID, PAYMENT_HASH, ROLE_HASH, block.timestamp + 1 days, hex"1234");
    }
}
