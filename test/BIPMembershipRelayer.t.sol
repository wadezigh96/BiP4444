// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BIPMembershipController} from "../contracts/src/BIPMembershipController.sol";
import {MockERC8004Identity} from "./mocks/MockERC8004Identity.sol";

/// @dev Focused tests for the new relayer path. These tests do not prove payment settlement.
contract BIPMembershipRelayerTest is Test {
    BIPMembershipController internal controller;
    MockERC8004Identity internal identity;

    address internal admin = address(0xA11CE);
    address internal alice = address(0xA11CE1);
    address internal relayer = address(0xB402);
    address internal stranger = address(0xBAD);
    uint256 internal constant AGENT_ID = 1001;

    function setUp() public {
        identity = new MockERC8004Identity();
        vm.prank(admin);
        controller = new BIPMembershipController(address(identity));
        identity.setOwner(AGENT_ID, alice);
    }

    function test_RelayerCanRegisterForIdentityOwner() public {
        vm.prank(admin);
        controller.setRelayer(relayer, true);

        vm.prank(relayer);
        vm.expectEmit(true, true, true, true);
        emit BIPMembershipController.MembershipRegistered(AGENT_ID, 1, relayer);
        controller.registerFor(AGENT_ID);

        assertTrue(controller.isMember(AGENT_ID));
        assertEq(controller.activeMemberCount(), 1);
        (uint256 id, address registeredBy,, bool active) = controller.membershipOf(AGENT_ID);
        assertEq(id, 1);
        assertEq(registeredBy, alice);
        assertTrue(active);
    }

    function test_RegisterFor_RevertsForNonRelayer() public {
        vm.prank(stranger);
        vm.expectRevert(BIPMembershipController.NotRelayer.selector);
        controller.registerFor(AGENT_ID);
    }

    function test_SetRelayer_OnlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(BIPMembershipController.NotOwner.selector);
        controller.setRelayer(relayer, true);
    }

    function test_SetRelayer_RejectsZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(BIPMembershipController.ZeroAddress.selector);
        controller.setRelayer(address(0), true);
    }

    function test_DisabledRelayerCannotRegister() public {
        vm.prank(admin);
        controller.setRelayer(relayer, true);
        vm.prank(admin);
        controller.setRelayer(relayer, false);

        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.NotRelayer.selector);
        controller.registerFor(AGENT_ID);
    }

    function test_RegisterFor_RevertsWhenPaused() public {
        vm.prank(admin);
        controller.setRelayer(relayer, true);
        vm.prank(admin);
        controller.pause();

        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.PausedError.selector);
        controller.registerFor(AGENT_ID);
    }

    function test_RegisterFor_RevertsOnZeroAgentId() public {
        vm.prank(admin);
        controller.setRelayer(relayer, true);
        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.ZeroAgentId.selector);
        controller.registerFor(0);
    }

    function test_RegisterFor_RevertsOnDuplicate() public {
        vm.prank(admin);
        controller.setRelayer(relayer, true);
        vm.prank(relayer);
        controller.registerFor(AGENT_ID);

        vm.prank(relayer);
        vm.expectRevert(BIPMembershipController.AlreadyMember.selector);
        controller.registerFor(AGENT_ID);
    }

    function test_RegisterFor_RevertsWhenAgentDoesNotExist() public {
        vm.prank(admin);
        controller.setRelayer(relayer, true);
        vm.prank(relayer);
        vm.expectRevert(MockERC8004Identity.NonexistentAgent.selector);
        controller.registerFor(9999);
    }
}
