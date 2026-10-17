// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC8004Identity} from "../contracts/interfaces/IERC8004Identity.sol";

/// @dev Read-only fork smoke test. It never signs or broadcasts a transaction.
contract BIPMembershipForkTest is Test {
    address internal constant ERC8004_IDENTITY = 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432;

    event ForkTestSkipped(string reason);

    function testFork_ERC8004RegistryOwnerOfIsReadable() public {
        string memory rpcUrl = vm.envOr("BSC_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            emit ForkTestSkipped("Set BSC_RPC_URL to execute the read-only BSC fork check.");
            return;
        }

        vm.createSelectFork(rpcUrl);
        assertEq(block.chainid, 56, "BSC RPC must resolve to chainId 56");
        assertGt(ERC8004_IDENTITY.code.length, 0, "ERC-8004 identity registry has no code");

        IERC8004Identity registry = IERC8004Identity(ERC8004_IDENTITY);
        address sampledOwner = registry.ownerOf(1);
        assertTrue(sampledOwner != address(0), "ownerOf(1) returned zero address");
    }
}
