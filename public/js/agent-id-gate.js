// BIP4444 — Agent ID Gate demo client
// Talks to the live SPACE ID Agent ID contract on BSC for ownership checks,
// and to BIPAgentIDGate once it is deployed.
//
// After deploying the gate (scripts/DeployAgentIDGate.s.sol), paste the
// deployed address into GATE_ADDRESS below and redeploy the site.

import { ethers } from "https://cdn.jsdelivr.net/npm/ethers@6.13.4/+esm";

export const AGENT_ID_ADDRESS = "0x60b9262456de011f7d15a54cdd8c48baaa8b022f";
export const ERC8004_ADDRESS = "0x8004A169FB4a3325136EB29fA0ceB6D2e539a432";
export const GATE_ADDRESS = ""; // <-- set after deployment
export const BSC_CHAIN_ID = 56;
export const BSC_RPC = "https://bsc-dataseed.binance.org";

const AGENT_ID_ABI = ["function balanceOf(address owner) view returns (uint256)"];
const GATE_ABI = [
  "function hasAgentID(address wallet) view returns (bool)",
  "function isRegistered(address wallet) view returns (bool)",
  "function uniqueAgentIDInteractors() view returns (uint256)",
  "function totalCapabilityGrants() view returns (uint256)",
  "function registerOperator()",
  "function registerAgent(uint256 erc8004AgentId)",
  "function foundingCount() view returns (uint256)",
  "function isFounding(address wallet) view returns (bool)",
  "function foundingSeatOf(address wallet) view returns (uint256)",
  "function setGuardian(address guardian)",
  "function freeze()",
  "function unfreeze()",
  "function isFrozen(address operator) view returns (bool)",
  "function grantCapability(address delegate, bytes32 scope, uint64 expiresAt) returns (uint256)",
  "function isAuthorized(address grantor, address delegate, bytes32 scope, uint256 capabilityId) view returns (bool)",
];

export function readProvider() {
  return new ethers.JsonRpcProvider(BSC_RPC);
}

export function agentIDContract(providerOrSigner) {
  return new ethers.Contract(AGENT_ID_ADDRESS, AGENT_ID_ABI, providerOrSigner);
}

export function gateContract(providerOrSigner) {
  if (!GATE_ADDRESS) return null;
  return new ethers.Contract(GATE_ADDRESS, GATE_ABI, providerOrSigner);
}

/// Check Agent ID ownership for any address — read-only, no wallet needed.
export async function checkAgentID(address) {
  if (!ethers.isAddress(address)) throw new Error("Invalid address");
  const bal = await agentIDContract(readProvider()).balanceOf(address);
  return bal > 0n;
}

/// Connect the user's wallet and make sure it is on BSC mainnet.
/// Uses the wallet's own confirmation UI for every transaction — this demo
/// never signs anything without the user pressing a button.
export async function connectWallet() {
  if (!window.ethereum) throw new Error("No wallet found. Open this page in Binance Wallet or a browser with a Web3 wallet.");
  const provider = new ethers.BrowserProvider(window.ethereum);
  await provider.send("eth_requestAccounts", []);
  const network = await provider.getNetwork();
  if (Number(network.chainId) !== BSC_CHAIN_ID) {
    await provider.send("wallet_switchEthereumChain", [{ chainId: "0x38" }]);
  }
  const signer = await provider.getSigner();
  return { provider, signer, address: await signer.getAddress() };
}

export function scopeFromLabel(label) {
  // Convention: keccak256("domain:action"), e.g. "bip4444:alerts:receive"
  return ethers.id(label.trim());
}
