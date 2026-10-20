# BIP4444 Read-Only Security Review — 2026-10-21

**Repository:** `wadezigh96/BiP4444`  
**Reviewed branch:** `audit/relayer-2step-ownership-4usdt`  
**Reviewed PR head:** `ceb2e1fb7a164b02f52a4d5b0e9fc67ee793a751`  
**Scope:** Read-only source review of the membership controller, B402 adapter, Alert Shield verifier, fork-test gate, and audit-gate documentation. No code execution against Mainnet, no payment, no deployment, and no state-changing transaction was performed.

## Current CI evidence

GitHub Actions run [39181224188](https://github.com/wadezigh96/BiP4444/actions/runs/39181224188) completed successfully for both the API/Foundry job and the Slither job. The Vercel status check on the PR head also reports success. These results establish that the configured checks completed; they do not establish production readiness or replace independent review.

## Findings — release blockers

### R1 — Payment requirements are not yet anchored to the live supported-kind response

`lib/b402-client.js` validates the fixed network, amount, token, and recipient, and checks that the signed `accepted.extra` equals the caller-supplied requirements. However, the client does not itself prove that the supplied `extra` object was selected from a fresh, trusted `/supported` response. Before integration, the server must select the exact supported kind from B402's response, preserve the complete object, and reject any client-supplied replacement. Add negative tests for an unsupported signer/spender and for a stale or changed supported-kind response.

### R2 — No durable payment ledger or cross-request idempotency

The adapter keeps verified payer state in an in-memory `Map` scoped to one client instance. This is not durable across serverless invocations, process restarts, or concurrent instances. The public registration API is correctly disabled, but the future integration must use a persistent ledger with unique payment/operation identifiers, atomic state transitions, replay protection, and reconciliation for timeouts or ambiguous settlement results. Do not enable live settlement until these exist and have failure-injection tests.

### R3 — Settlement success is not the same as confirmed on-chain receipt

The adapter checks the provider envelope, payer, network, amount, success flag, and non-empty transaction field. It does not independently confirm the transaction receipt/finality on BSC. The integration must treat ambiguous or pending provider states as pending, reconcile using a trusted source, and never register or refund solely because a request timed out or returned an ambiguous result.

### R4 — Alert Shield trust directory has no anchored trust root in the verifier

`verifyAlert(envelope, keyDirectory)` validates keys supplied as an argument, but this function does not authenticate the key directory itself. If production code accepts a directory controlled by the same untrusted feed or request as the alert, an attacker could supply their own signing key and a matching directory. Production integration must pin or cryptographically authenticate the directory through a separate trusted channel, define rollback/freshness handling, reject duplicate key IDs, and test key rotation/revocation. The current empty publisher directory and absent live signing/feed service remain blockers.

### R5 — ERC-8004 transfer-away-and-back authorization edge case remains

The controller cannot observe ERC-8004 transfers. The 15-minute deadline and `invalidateAuthorization(agentId)` reduce exposure but do not eliminate a transfer-away-and-back within the signature lifetime. Keep this explicitly documented; do not describe the issue as fixed. Independent contract review must decide whether the residual risk is acceptable before release.

### R6 — Live BSC fork evidence is still missing

The fork test returns early when `BSC_RPC_URL` is absent unless `BIP_REQUIRE_LIVE_FORK=1`. The ordinary CI success therefore does not prove the live fork assertion ran. Run the test using a read-only BSC RPC with `BIP_REQUIRE_LIVE_FORK=1`, confirm chain ID 56 and registry code/ownerOf behavior, and save the output as evidence. No transaction is required.

## Additional review notes

- The API registration scaffold remains fail-closed and returns `503 REGISTRATION_DISABLED`; keep it that way.
- Slither runs with `--fail-none`; the five informational findings recorded in `docs/evidence/SLITHER_2026-10-19.md` require human review and are not a clean-bill-of-health.
- Alert link validation currently restricts links to HTTPS on `bips4444.vercel.app`; verify that this is the final official production hostname before enabling alerts.
- No independent security audit, production B402 onboarding, durable refund flow, or release approval has been evidenced.

## Decision

**NOT READY FOR PRODUCTION. Do not merge this draft, enable payments, deploy the controller, or perform state-changing Mainnet transactions.** Next implementation work should remain on this feature branch and address the blockers with tests first. BSC Mainnet remains the target; no Testnet transactions are requested.
