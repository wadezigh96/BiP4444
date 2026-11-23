// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BIPAgentIDGate} from "../contracts/src/BIPAgentIDGate.sol";

/// @title Deploy BIPAgentIDGate
/// @notice Foundry deployment script for the Agent ID gate (BNB Smart Chain).
/// @dev Usage:
///   forge script scripts/DeployAgentIDGate.s.sol:DeployAgentIDGate \
///     --rpc-url $BSC_RPC_URL \
///     --private-key $DEPLOYER_PRIVATE_KEY \
///     --broadcast \
///     --verify
///
/// After deployment:
///   1. Verify the contract source on BscScan (hackathon requirement).
///   2. (Optional) transferOwnership to a multisig.
///   3. Submit the deployed address in the hackathon submission form.
contract DeployAgentIDGate is Script {
    // BSC mainnet — SPACE ID Agent ID (ERC-721, non-transferable)
    address constant AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    // BSC mainnet — ERC-8004 Identity Registry (proxy)
    address constant ERC8004_IDENTITY = 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        BIPAgentIDGate gate = new BIPAgentIDGate(AGENT_ID, ERC8004_IDENTITY);

        vm.stopBroadcast();

        console.log("BIPAgentIDGate deployed at:", address(gate));
        console.log("Owner:", deployer);
        console.log("Agent ID contract:", AGENT_ID);
        console.log("Identity registry:", ERC8004_IDENTITY);
    }
}
