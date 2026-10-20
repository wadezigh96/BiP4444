// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {BIPMembershipController} from "../contracts/src/BIPMembershipController.sol";

/// @title Deploy BIPMembershipController
/// @notice Example Foundry deployment script.
/// @dev Usage:
///   forge script scripts/Deploy.s.sol:Deploy \
///     --rpc-url $BSC_RPC_URL \
///     --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast \
///     --verify
///
/// After deployment:
///   1. Call setRelayer(relayerAddress) as owner
///   2. (Optional) transferOwnership to a multisig
contract Deploy is Script {
    // BSC mainnet ERC-8004 Identity Registry (proxy)
    address constant ERC8004_IDENTITY = 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        BIPMembershipController controller = new BIPMembershipController(ERC8004_IDENTITY);

        // Optional: set relayer immediately if RELAYER_ADDRESS is provided
        try vm.envAddress("RELAYER_ADDRESS") returns (address relayer) {
            if (relayer != address(0)) {
                controller.setRelayer(relayer);
            }
        } catch {}

        vm.stopBroadcast();

        console.log("BIPMembershipController deployed at:", address(controller));
        console.log("Owner:", deployer);
        console.log("Identity registry:", ERC8004_IDENTITY);
    }
}
