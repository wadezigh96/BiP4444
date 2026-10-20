#!/usr/bin/env node
/**
 * BIP4444 — Path A Relayer example (x402 / B402 → registerFor)
 *
 * Flow:
 *   1. Client pays 5 USDT via x402 (EIP-712 / Permit2) to Safe payTo
 *   2. Backend receives payment signature + agentId + role
 *   3. Call B402 /verify
 *   4. Call B402 /settle
 *   5. On success → relayer calls BIPMembershipController.registerFor(agentId)
 *   6. If register fails after settle → mark for refund (5 USDT back to payer)
 *
 * Secrets (never commit):
 *   B402_BASE_URL
 *   B402_API_KEY / B402_API_SECRET   (or RSA client credentials for Binance B402)
 *   RELAYER_PRIVATE_KEY              (EOA that can call registerFor)
 *   MEMBERSHIP_CONTROLLER_ADDRESS    (deployed BIPMembershipController)
 *   BSC_RPC_URL
 *
 * This is a skeleton. Replace the B402 client with the real authenticated calls
 * once partner credentials are available.
 */

const { ethers } = require("ethers"); // optional: npm i ethers

// ---------------------------------------------------------------------------
// Config (from env)
// ---------------------------------------------------------------------------
const CONFIG = {
  b402BaseUrl: process.env.B402_BASE_URL || "https://facilitatorv3.b402.ai",
  // Binance official B402 uses authenticated /papi/v2/b402/* — see docs
  payTo: "0xFf265912c76342c8469cE18aB9DF0B2f37d9373c",
  asset: "0x55d398326f99059fF775485246999027B3197955", // USDT BSC
  amountAtomic: "5000000000000000000", // 5 USDT (18 decimals)
  chainId: 56,
  membershipController: process.env.MEMBERSHIP_CONTROLLER_ADDRESS,
  relayerKey: process.env.RELAYER_PRIVATE_KEY,
  rpcUrl: process.env.BSC_RPC_URL || "https://bsc-dataseed.binance.org",
};

// Minimal ABI for registerFor
const CONTROLLER_ABI = [
  "function registerFor(uint256 agentId) external",
  "function isMember(uint256 agentId) view returns (bool)",
  "function relayer() view returns (address)",
];

// ---------------------------------------------------------------------------
// In-memory ledger (replace with DB in production)
// ---------------------------------------------------------------------------
const ledger = new Map(); // paymentId → { status, agentId, role, txHash, ... }

function makePaymentId(agentId, payer, nonce) {
  return ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(
      ["uint256", "address", "bytes32"],
      [agentId, payer, nonce || ethers.ZeroHash]
    )
  );
}

// ---------------------------------------------------------------------------
// B402 client (placeholder — replace with real authenticated calls)
// ---------------------------------------------------------------------------
async function b402Verify(paymentPayload) {
  // Real call example (adjust path & auth for your B402 surface):
  // POST ${CONFIG.b402BaseUrl}/verify
  // or Binance: POST .../papi/v2/b402/verify  (RSA-signed)
  console.log("[b402] verify", { payTo: paymentPayload.payTo, amount: paymentPayload.amount });

  // Skeleton: assume success for demo. Replace with real fetch.
  return {
    ok: true,
    payer: paymentPayload.payer || "0x0000000000000000000000000000000000000000",
    paymentId: paymentPayload.paymentId,
  };
}

async function b402Settle(paymentPayload) {
  console.log("[b402] settle", paymentPayload.paymentId);
  // Real call: POST /settle → returns { success, transaction }
  return {
    ok: true,
    txHash: "0x" + "ab".repeat(32), // placeholder
  };
}

// ---------------------------------------------------------------------------
// On-chain registration
// ---------------------------------------------------------------------------
async function registerFor(agentId) {
  if (!CONFIG.membershipController || !CONFIG.relayerKey) {
    throw new Error("Set MEMBERSHIP_CONTROLLER_ADDRESS and RELAYER_PRIVATE_KEY");
  }

  const provider = new ethers.JsonRpcProvider(CONFIG.rpcUrl);
  const wallet = new ethers.Wallet(CONFIG.relayerKey, provider);
  const controller = new ethers.Contract(
    CONFIG.membershipController,
    CONTROLLER_ABI,
    wallet
  );

  // Optional: check that this wallet is the designated relayer
  const onChainRelayer = await controller.relayer();
  if (onChainRelayer.toLowerCase() !== wallet.address.toLowerCase()) {
    throw new Error(`Relayer mismatch: on-chain=${onChainRelayer} local=${wallet.address}`);
  }

  const tx = await controller.registerFor(agentId);
  const receipt = await tx.wait();
  return receipt.hash;
}

// ---------------------------------------------------------------------------
// Main flow
// ---------------------------------------------------------------------------
async function handleRegistration({ agentId, role, paymentPayload }) {
  const paymentId = paymentPayload.paymentId || makePaymentId(agentId, paymentPayload.payer);

  // Idempotency
  if (ledger.has(paymentId)) {
    const existing = ledger.get(paymentId);
    console.log("[ledger] already processed", existing.status);
    return existing;
  }

  ledger.set(paymentId, { status: "pending", agentId, role });

  try {
    // 1. Verify
    const verify = await b402Verify({ ...paymentPayload, paymentId });
    if (!verify.ok) throw new Error("B402 verify failed");

    // Hard checks
    if (paymentPayload.payTo?.toLowerCase() !== CONFIG.payTo.toLowerCase()) {
      throw new Error("payTo mismatch — must be the Safe");
    }
    if (paymentPayload.amount !== CONFIG.amountAtomic) {
      throw new Error("amount mismatch — must be exactly 5 USDT");
    }

    // 2. Settle
    const settle = await b402Settle({ ...paymentPayload, paymentId });
    if (!settle.ok) throw new Error("B402 settle failed");

    ledger.set(paymentId, { status: "settled", agentId, role, settleTx: settle.txHash });

    // 3. Register on-chain
    const registerTx = await registerFor(agentId);
    ledger.set(paymentId, {
      status: "registered",
      agentId,
      role,
      settleTx: settle.txHash,
      registerTx,
    });

    console.log("[success] membership registered", { agentId, registerTx });
    return ledger.get(paymentId);
  } catch (err) {
    const current = ledger.get(paymentId);
    if (current?.status === "settled") {
      // Settle succeeded but register failed → refund required
      ledger.set(paymentId, {
        ...current,
        status: "refund_required",
        error: err.message,
      });
      console.error("[refund required]", err.message);
      // TODO: trigger Safe refund of 5 USDT to payer (manual or automated)
    } else {
      ledger.set(paymentId, { status: "failed", agentId, error: err.message });
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// CLI demo (replace with real HTTP handler)
// ---------------------------------------------------------------------------
if (require.main === module) {
  const demoAgentId = process.argv[2] || "1001";
  handleRegistration({
    agentId: BigInt(demoAgentId),
    role: "agent",
    paymentPayload: {
      payTo: CONFIG.payTo,
      amount: CONFIG.amountAtomic,
      asset: CONFIG.asset,
      payer: "0x0000000000000000000000000000000000000001",
      // real payload would contain the signed EIP-712 / Permit2 authorization
    },
  })
    .then((result) => console.log(JSON.stringify(result, null, 2)))
    .catch((e) => {
      console.error(e.message);
      process.exit(1);
    });
}

module.exports = { handleRegistration, CONFIG };
