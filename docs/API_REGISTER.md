# BIP4444 Membership Register API — v1

**Status:** Implementation contract / not production-enabled  
**Network:** BNB Smart Chain mainnet, CAIP-2 `eip155:56` (specification only; no mainnet transactions authorized)  
**Canonical endpoint:** `POST /v1/membership/register`  
**Related locked design:** `docs/X402_REQUIREMENTS.md`, `docs/MEMBERSHIP_CONTROLLER.md`, `docs/AUDIT_GATES.md`

## 1. Security and invariants

- The server is authoritative for the x402 payment terms. Clients MUST NOT choose or override network, asset, amount, `payTo`, facilitator, or settlement destination.
- Facilitator: B402. Price: exactly 5 USDT. Asset: `0x55d398326f99059fF775485246999027B3197955` (18 decimals). Atomic amount: `5000000000000000000`.
- The only allowed `payTo` is Safe `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`. Reject configuration drift at startup and fail closed; never fall back to an EOA or client-provided destination.
- Identity is an existing ERC-8004 `agentId` on BSC identity registry `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`. Resolve the current `ownerOf(agentId)` from chain before creating a payment requirement and again before registration. Do not trust a client-supplied owner.
- Before relayer registration, require a fresh EIP-712 authorization signed by the current ERC-8004 owner. The signature binds `agentId`, `paymentIdHash`, canonical `roleHash`, owner nonce, deadline, chain ID, and controller address. The contract rejects expired signatures, signatures valid for more than 24 hours, reused payment hashes, and invalid signatures. A payment settlement alone is not owner consent.
- `role` is a validated, bounded off-chain string in v1. It is not authorization to control the agent or its wallet.
- One settled `paymentId` may grant at most one membership. Enforce with database uniqueness/transactional state transitions, not process memory.
- Membership cap 4,444 is enforced on-chain and is authoritative. A preflight count is informational only; handle the on-chain cap rejection and refund policy.
- Never log payment signatures, authorization headers, secrets, private keys, full facilitator payloads containing credentials, or sensitive personal data.
- This document is a protocol contract, not evidence that B402 endpoints or SDK methods have been verified. Implement the facilitator adapter only after matching it to current official B402 documentation and recording the version/source in evidence.

## 2. Request

`POST /v1/membership/register` with `Content-Type: application/json`.

```json
{
  "agentId": "123",
  "role": "research"
}
```

Validation:
- `agentId`: required decimal string representing uint256; reject negatives, hex strings, whitespace, unsafe JS numbers, zero if registry policy disallows it, and values outside uint256.
- `role`: required string, trim outer whitespace, 1–64 UTF-8 bytes, allow a conservative set of letters/numbers plus `._:-`; reject control characters and markup. Canonicalize before hashing or idempotency comparisons.
- Reject unknown properties (including `payTo`, `amount`, `asset`, `chainId`, `network`, `facilitator`, `owner`, `paymentId`, and `transactionHash`) with `400 INVALID_REQUEST`. The server creates and owns payment/session identifiers.
- Require an authenticated/authorized wallet session or a cryptographically valid x402 payment payload according to the finalized B402 flow. Authentication does not replace payment verification.

## 3. Initial 402 response

When the request is valid but payment has not been provided, return HTTP `402 Payment Required`. Construct the x402 v2 payment requirement from server-side constants and the verified B402-supported scheme. The response MUST use the standard `PAYMENT-REQUIRED` header and its protocol-defined encoding, and include a safe JSON body for clients that do not parse the header.

Example body (illustrative application fields; the actual x402 header must follow the selected B402/x402 SDK specification):

```json
{
  "error": {
    "code": "PAYMENT_REQUIRED",
    "message": "Payment of 5 USDT is required to register this membership.",
    "retryable": true
  },
  "payment": {
    "protocol": "x402",
    "version": 2,
    "network": "eip155:56",
    "asset": "0x55d398326f99059fF775485246999027B3197955",
    "amount": "5000000000000000000",
    "payTo": "0xFf265912c76342c8469cE18aB9DF0B2f37d9373c",
    "resource": "/v1/membership/register"
  }
}
```

The JSON fields above are explanatory and do not substitute for the canonical x402 `PAYMENT-REQUIRED` header. Never invent B402 header encoding or SDK fields; use the current official implementation.

## 4. Payment retry and processing

The client retries the same endpoint with the protocol-required `PAYMENT-SIGNATURE` header after obtaining user approval/signature. Do not accept payment data from a JSON body as a substitute for the required protocol header.

Server state machine, persisted transactionally:

`CREATED → PAYMENT_VERIFIED → SETTLEMENT_PENDING → SETTLED → REGISTRATION_PENDING → REGISTERED`

Failure branches:
- `PAYMENT_REJECTED`: verification failed; do not settle, register, or refund an un-settled payment.
- `SETTLEMENT_UNKNOWN`: timeout/ambiguous result; reconcile with B402 by stable facilitator reference before retrying settlement. Never blindly settle twice.
- `SETTLEMENT_FAILED`: no membership; preserve redacted evidence and allow safe retry only according to B402 idempotency semantics.
- `REGISTRATION_FAILED_REFUND_PENDING`: settlement succeeded but registration definitively failed; enqueue exactly one refund to the verified payer for 5 USDT and alert operations.
- `REFUND_PENDING → REFUNDED` or `REFUND_FAILED_MANUAL_REVIEW`: retry only with provider-supported idempotency/reconciliation; do not send a second refund because of a timeout.
- `REGISTERED`: terminal success for that paymentId. Replays return the same result and MUST NOT create a second membership.

Use a stable server-generated operation/idempotency key across retries. Persist the facilitator's payment/settlement reference and normalized payer address. Never infer the payer from an unverified request field. Database uniqueness constraints MUST cover facilitator payment ID and successful membership grant. The DB transaction cannot atomically include an external chain transaction; use an outbox/job pattern plus reconciliation.

## 4A. Owner consent for relayer registration

The relayer contract does not accept a bare `registerFor(agentId)` call. After B402 settlement is confirmed, the backend must ask the authenticated current ERC-8004 owner to sign an EIP-712 authorization. The signature is not a payment signature and does not replace B402 verification.

Domain:
- `name`: `BIP4444 Membership Controller`
- `version`: `1`
- `chainId`: `56` for BSC mainnet (use the matching chain in isolated test environments)
- `verifyingContract`: the deployed membership controller address

Typed data:
```json
{
  "MembershipAuthorization": [
    { "name": "agentId", "type": "uint256" },
    { "name": "paymentIdHash", "type": "bytes32" },
    { "name": "roleHash", "type": "bytes32" },
    { "name": "nonce", "type": "uint256" },
    { "name": "deadline", "type": "uint256" }
  ]
}
```

- `paymentIdHash = keccak256(UTF8(server-generated internal payment operation ID))`; do not accept a client-chosen payment ID.
- `roleHash = keccak256(UTF8(canonical validated role string))`; use the exact same canonicalization on client and server.
- Read the current owner nonce from the contract immediately before requesting the signature. A stale nonce must fail closed and require a new signature.
- Deadline must be in the future and no more than 24 hours ahead. Prefer a shorter operational lifetime (for example, 10–15 minutes).
- Backend must verify that B402's confirmed settled payment ID maps to this exact operation and that the payer/owner binding follows the product's authorization policy. Never infer payment identity from client JSON.
- Call `registerFor(agentId, paymentIdHash, roleHash, deadline, ownerSignature)` only after settlement confirmation. The contract checks owner consent and marks the payment hash used. A contract success does **not** independently prove that B402 settled; the relayer and durable ledger remain critical trust boundaries.
- Persist the typed-data fields, signature-verification result, B402 settlement reference, and transaction hash with secrets/signatures redacted where possible. Do not log the raw signature.

## 5. Successful response

Return HTTP `200 OK` only after settlement is confirmed and the on-chain registration is confirmed at the required confirmation policy. Include `PAYMENT-RESPONSE` using the selected x402 SDK's canonical format.

```json
{
  "ok": true,
  "membership": {
    "agentId": "123",
    "role": "research",
    "status": "active",
    "chainId": 56,
    "transactionHash": "0x…"
  },
  "payment": {
    "status": "settled",
    "asset": "0x55d398326f99059fF775485246999027B3197955",
    "amount": "5000000000000000000",
    "payTo": "0xFf265912c76342c8469cE18aB9DF0B2f37d9373c"
  }
}
```

Never return a success response based only on a submitted transaction hash, a facilitator request being accepted, or a transaction being broadcast. If registration is pending, return `202 REGISTRATION_PENDING` with an opaque operation ID and a status URL; no membership success claim.

## 6. Error response contract

All non-402 errors use a stable JSON envelope:

```json
{
  "error": {
    "code": "INVALID_REQUEST",
    "message": "The request is invalid.",
    "retryable": false,
    "requestId": "opaque-id"
  }
}
```

| HTTP | Code | Meaning / policy |
|---:|---|---|
| 400 | `INVALID_REQUEST` | Missing/invalid fields or forbidden client-controlled payment fields |
| 401 | `AUTH_REQUIRED` | Required session/authentication absent or invalid |
| 403 | `AGENT_NOT_OWNED` | Authenticated wallet does not currently own the agent, where ownership binding is required |
| 404 | `AGENT_NOT_FOUND` | ERC-8004 identity does not exist |
| 409 | `ALREADY_MEMBER` | Agent already has active membership; do not charge again |
| 409 | `IDEMPOTENCY_CONFLICT` | Same idempotency key used for different canonical request |
| 409 | `PAYMENT_ALREADY_USED` | Payment ID already bound to another grant or request |
| 402 | `PAYMENT_REQUIRED` | Payment required; include canonical x402 header |
| 422 | `PAYMENT_INVALID` | Invalid, expired, wrong-network, wrong-asset, wrong-amount, or wrong-payTo payment |
| 429 | `RATE_LIMITED` | Rate limit exceeded; include safe retry guidance |
| 503 | `FACILITATOR_UNAVAILABLE` | B402 unavailable; fail closed, do not grant membership |
| 503 | `SETTLEMENT_UNKNOWN` | Settlement outcome needs reconciliation; never blindly repeat |
| 503 | `REGISTRATION_PENDING` | Settlement known, registration job not yet final |
| 500 | `INTERNAL_ERROR` | Unexpected error; no secret or raw provider details in response |

For errors after a confirmed settlement, response and operations state must clearly indicate whether a refund is pending. Never report a refund as completed until confirmed.

## 7. Idempotency and ledger minimum

Recommended relational records:
- `membership_payment`: internal operation ID, canonical request hash, agentId, normalized role, payer, amount, asset, payTo, chainId, state, timestamps.
- `facilitator_payment`: provider payment ID/reference (unique), verification status, settlement status/reference, redacted response metadata.
- `membership_grant`: agentId (unique for the active membership policy), payment operation ID (unique), chain transaction hash (unique when present), status.
- `refund_job`: source payment ID (unique), payer, amount, state, provider reference, attempts, last error category, timestamps.
- `outbox_job`: unique operation/action key, state, attempts and scheduling metadata.

Use DB transactions for state transitions and uniqueness. Encrypt sensitive operational metadata at rest as appropriate. Never store raw payment signatures longer than strictly required by the verified facilitator protocol; prefer hashes and redacted evidence.

## 8. Refund runbook contract

A refund is eligible only when B402 settlement is confirmed and registration has definitively failed (not merely timed out). Refund exactly 5 USDT to the verified original payer, never to a client-provided destination. A single durable refund job per settled payment is required. Reconcile ambiguous refund outcomes with B402 before retrying. If the facilitator cannot refund directly, document and require Safe 2-of-2 approval; never let a relayer key unilaterally move Safe funds.

## 9. Required negative/integration tests

- Wrong network, token, amount, payTo, expired payload, invalid signature, unsupported scheme, and replayed payment.
- Missing/malformed `PAYMENT-SIGNATURE`; forged JSON payment fields; client attempts to override payTo.
- B402 verification rejection, timeout, rate limit, and malformed response; fail closed.
- Settlement failure and ambiguous settlement timeout; reconciliation without duplicate settlement.
- Registration revert (cap reached, duplicate agentId, paused controller), relayer failure, RPC timeout, and chain reorg handling.
- Settle success + register failure creates one refund job; duplicate retry creates no second refund.
- Duplicate concurrent requests for the same paymentId or agentId create at most one membership.
- Database restart/retry preserves state; secrets are absent from logs and responses.
- Role validation, unknown fields, uint256 boundaries, rate limits, and unauthorized callers.
- Assert that no test sends a real mainnet transaction; use mocks and local/testnet fixtures.

## 10. Release blockers

This API is **not production-ready** until:
1. Official B402 API/SDK docs and supported x402 v2 header encoding are verified and pinned.
2. Persistent database and transactional idempotency are implemented.
3. B402 verify/settle/refund integration tests pass against mocks, then testnet/sandbox where available.
4. `registerFor` access control, relayer key management, cap and duplicate handling pass independent contract review.
5. Alert/auth/privacy/rate-limit tests and all `docs/AUDIT_GATES.md` gates pass.
6. Independent review and explicit release approval are recorded.

No mainnet deployment, live payment, or mainnet transaction is authorized by this document.
