// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Vm} from "forge-std/Vm.sol";
import {BIPMembershipController} from "../contracts/src/BIPMembershipController.sol";
import {MockERC8004Identity} from "./mocks/MockERC8004Identity.sol";

/// @dev Stateful fuzz handler for registration and self-revocation.
contract MembershipInvariantHandler {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    BIPMembershipController public immutable controller;
    MockERC8004Identity public immutable identity;
    uint256 private _paymentSequence;

    bytes32 private constant ROLE_HASH = keccak256("invariant-role");

    constructor(BIPMembershipController controller_, MockERC8004Identity identity_) {
        controller = controller_;
        identity = identity_;
    }

    function register(uint256 seed) external {
        uint256 agentId = 1 + (seed % 20);
        uint256 ownerKey = agentId + 0xA11CE;
        address agentOwner = vm.addr(ownerKey);
        identity.setOwner(agentId, agentOwner);

        if (controller.isMember(agentId)) return;

        bytes32 paymentHash = keccak256(abi.encode("invariant-payment", ++_paymentSequence, agentId));
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = controller.authorizationDigest(
            agentId, paymentHash, ROLE_HASH, controller.ownerNonces(agentOwner), deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        try controller.registerFor(agentId, paymentHash, ROLE_HASH, deadline, signature) {
            // Registration succeeded.
        } catch {
            // Invalid/reverted actions are expected during stateful fuzzing.
        }
    }

    function revoke(uint256 seed) external {
        uint256 agentId = 1 + (seed % 20);
        if (!controller.isMember(agentId)) return;

        uint256 ownerKey = agentId + 0xA11CE;
        address agentOwner = vm.addr(ownerKey);
        identity.setOwner(agentId, agentOwner);

        vm.prank(agentOwner);
        try controller.revokeSelf(agentId) {
            // Self-revocation succeeded.
        } catch {
            // Invalid/reverted actions are expected during stateful fuzzing.
        }
    }
}

contract BIPMembershipInvariantTest is StdInvariant, Test {
    BIPMembershipController internal controller;
    MockERC8004Identity internal identity;
    MembershipInvariantHandler internal handler;

    function setUp() public {
        identity = new MockERC8004Identity();
        controller = new BIPMembershipController(address(identity));
        handler = new MembershipInvariantHandler(controller, identity);
        controller.setRelayer(address(handler), true);
        targetContract(address(handler));
    }

    /// @notice Active count can never exceed the hard protocol cap.
    function invariant_ActiveCountNeverExceeds4444() public view {
        assertLe(controller.activeMemberCount(), 4444);
    }

    /// @notice The public active count always matches membership state for the handler's bounded agent set.
    function invariant_ActiveCountMatchesMembershipFlags() public view {
        uint256 counted;
        for (uint256 agentId = 1; agentId <= 20; ++agentId) {
            (,,, bool active) = controller.membershipOf(agentId);
            assertEq(controller.isMember(agentId), active);
            if (active) ++counted;
        }
        assertEq(controller.activeMemberCount(), counted);
    }
}
