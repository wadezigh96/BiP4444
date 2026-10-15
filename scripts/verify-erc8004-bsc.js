/**
 * BIP4444 — ERC-8004 Identity Registry verification helper (BSC mainnet)
 *
 * Usage (Node 18+):
 *   node scripts/verify-erc8004-bsc.js
 *
 * Optional env:
 *   BSC_RPC_URL   (default: https://bsc-dataseed.bnbchain.org)
 *   AGENT_ID      (optional agentId to probe ownerOf)
 *
 * This script is for planning / evidence collection only.
 * It does not modify chain state.
 */

const IDENTITY_REGISTRY = "0x8004A169FB4a3325136EB29fA0ceB6D2e539a432";
const REPUTATION_REGISTRY = "0x8004BAa17C55a88189AE136b182e5fdA19dE9b63";
const EXPECTED_CHAIN_ID = 56n;

const MINIMAL_ABI = [
  "function ownerOf(uint256 tokenId) view returns (address)",
  "function supportsInterface(bytes4 interfaceId) view returns (bool)",
  "function name() view returns (string)",
  "function symbol() view returns (string)",
];

async function main() {
  const rpc = process.env.BSC_RPC_URL || "https://bsc-dataseed.bnbchain.org";
  const agentId = process.env.AGENT_ID ? BigInt(process.env.AGENT_ID) : null;

  // Dynamic import so the file can live in repo without forcing install until needed
  let ethers;
  try {
    ethers = await import("ethers");
  } catch {
    console.error("Please install ethers: npm install ethers");
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(rpc);
  const network = await provider.getNetwork();

  console.log("=== BIP4444 ERC-8004 BSC Verification ===");
  console.log("RPC:", rpc);
  console.log("Chain ID:", network.chainId.toString());
  console.log("Expected Chain ID:", EXPECTED_CHAIN_ID.toString());

  if (network.chainId !== EXPECTED_CHAIN_ID) {
    console.error("ERROR: Not connected to BSC mainnet (56).");
    process.exit(1);
  }

  const code = await provider.getCode(IDENTITY_REGISTRY);
  const hasCode = code && code !== "0x";
  console.log("\nIdentity Registry:", IDENTITY_REGISTRY);
  console.log("Has contract code:", hasCode);
  console.log("Code length (bytes):", hasCode ? (code.length - 2) / 2 : 0);

  const repCode = await provider.getCode(REPUTATION_REGISTRY);
  console.log("\nReputation Registry:", REPUTATION_REGISTRY);
  console.log("Has contract code:", repCode && repCode !== "0x");

  if (!hasCode) {
    console.error("\nFAIL: No code at Identity Registry address on BSC.");
    process.exit(1);
  }

  const registry = new ethers.Contract(IDENTITY_REGISTRY, MINIMAL_ABI, provider);

  try {
    const name = await registry.name();
    const symbol = await registry.symbol();
    console.log("\nname():", name);
    console.log("symbol():", symbol);
  } catch (e) {
    console.log("\nname()/symbol() not available or reverted:", e.shortMessage || e.message);
  }

  if (agentId !== null) {
    try {
      const owner = await registry.ownerOf(agentId);
      console.log(`\nownerOf(${agentId}):`, owner);
    } catch (e) {
      console.log(`\nownerOf(${agentId}) failed:`, e.shortMessage || e.message);
    }
  } else {
    console.log("\n(Set AGENT_ID env to probe a specific agentId with ownerOf)");
  }

  const block = await provider.getBlockNumber();
  console.log("\nVerified at block:", block);
  console.log("Timestamp (UTC):", new Date().toISOString());
  console.log("\n=== End of verification run ===");
  console.log("Record the output above in docs/evidence/ for the audit gate.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
