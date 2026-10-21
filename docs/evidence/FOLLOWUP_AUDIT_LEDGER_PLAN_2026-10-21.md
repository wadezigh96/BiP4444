# BIP4444 Follow-up Audit and Ledger Implementation Plan — 2026-10-21

**Repository:** `wadezigh96/BiP4444`  
**Branch:** `audit/relayer-2step-ownership-4usdt`  
**Scope:** Read-only review of current CI and source plus implementation plan. This document does not enable payments, registration, deployment, or state-changing Mainnet activity.

## Latest verified CI evidence

GitHub Actions run [39509984567](https://github.com/wadezigh96/BiP4444/actions/runs/39509984567) completed successfully on commit `2425751d50fd360bec90ca3ff25b4dfcea70aafe`. Both jobs completed successfully:

- API and Foundry tests (local only)
- Slither static analysis

The latest Alert Shield test additions use an existing `publicKeyBase64` helper and existing test key fixtures. Source inspection confirms the duplicate-ID test creates a duplicate `keyId` and the missing-ID test supplies an entry without a `keyId`. The verifier rejects both with `ALERT_KEY_DIRECTORY_INVALID`.

This CI run does **not** establish that a BSC Mainnet fork test ran. The fork gate remains open until a read-only RPC run uses `BIP_REQUIRE_LIVE_FORK=1` and its output is archived. Slither uses `--fail-none`, so its successful job is not a zero-findings assertion.

## Current safety posture

- The membership registration API returns `503 REGISTRATION_DISABLED`.
- The B402 client refuses settlement unless both `BIP_ENABLE_LIVE_SETTLEMENT=true` and `BIP_RELEASE_APPROVED=true` are set. Do not set these flags during this work.
- No durable payment ledger is implemented.
- B402's verified-payer cache is an in-memory `Map`, scoped to one client instance. It cannot safely coordinate retries or concurrent serverless instances.
- Settlement is not independently reconciled against a trusted BSC receipt/finality source.
- The verifier does not authenticate the key directory supplied to it; the directory's trust root and publisher process remain release blockers.
- ERC-8004 transfer-away-and-back authorization risk remains, despite the 15-minute expiry and invalidation method.
- Do not merge the draft PR, deploy, enable payments, or send state-changing Mainnet transactions.

## Next implementation unit: durable payment operation ledger

Implement and test this as an isolated module first. Do not wire it to the public registration route or call B402 settlement/relayer from it yet.

### Required records

A payment operation record should contain at minimum:

- A server-generated immutable operation ID.
- A unique payment fingerprint or provider payment identifier, with a database-enforced uniqueness constraint.
- A client idempotency key stored with a request hash; reusing the key with different request data must be rejected.
- Normalized agent ID and role hash (not arbitrary client-supplied payment policy).
- Expected chain, asset, atomic amount, and payTo policy version.
- State, created/updated timestamps, attempt count, and a sanitized error code.
- Verified payer and provider verification reference, where available.
- Settlement transaction hash and reconciliation state, where available.
- Registration transaction hash and membership ID, where available.
- Refund reference/state, where applicable.
- A version or compare-and-swap field for atomic transitions.

Do not store private keys, signing secrets, access tokens, or raw credentials in ledger rows or logs. Avoid storing full payment payloads unless required and reviewed; if retained, protect access and define a retention policy.

### State machine

Use explicit, validated transitions; never accept arbitrary state updates from the caller:

`created -> verified -> settlement_pending -> settled -> registration_pending -> registered`

Failure and recovery states must include at least:

- `verification_failed` — terminal for that payment attempt.
- `settlement_unknown` — provider/network outcome ambiguous; reconcile before retry.
- `settlement_failed` — only when failure is definitive.
- `registration_unknown` — transaction may have been submitted; reconcile before retry.
- `refund_pending -> refunded` — only after the policy authorizes refund and a unique refund operation is reserved.
- `manual_review` — conflicting or unresolvable evidence.

A timeout is not proof of failure. Do not refund or submit a second settlement merely because a request timed out. A database transaction must atomically reserve the payment/operation before any external side effect.

### Required storage guarantees

1. Database-enforced uniqueness for provider payment identity and operation/idempotency keys.
2. Atomic compare-and-swap or transactional state transitions.
3. A durable outbox or equivalent pattern for work that must be retried after a crash.
4. Lease/claim semantics for workers so two instances cannot settle/register/refund the same operation concurrently.
5. A reconciliation worker or operator procedure for ambiguous settlement, registration, and refund states.
6. Append-only audit events for state transitions, with secrets and sensitive payment data excluded.
7. Explicit retention, backup, access-control, and recovery expectations.

### Required tests before any API wiring

- Same idempotency key + same request returns the same operation.
- Same idempotency key + different request is rejected.
- Two concurrent requests cannot reserve the same payment.
- Two concurrent workers cannot advance one operation twice.
- Process restart does not lose verification/settlement state.
- Provider timeout after possible success enters an unknown/reconciliation state.
- Duplicate provider callback or retry does not double-settle, double-register, or double-refund.
- Wrong chain, asset, amount, payTo, payer binding, or unsupported kind is rejected.
- Registration failure after confirmed settlement follows a documented refund/recovery policy exactly once.
- Logs and public API errors never contain credentials, signatures, or full sensitive provider responses.

## Database selection gate

Do not pick a database by guesswork. Before implementation, inspect the project's existing Vercel-linked resources and the available supported database integrations. Select a provider only after confirming:

- It is connected to the correct Vercel project/team.
- It supports transactions or an equivalent atomic conditional-write mechanism and unique constraints.
- Credentials can be injected through server-only environment variables.
- Its free/paid limits, backups, region, and recovery model are acceptable.
- A local/mock test adapter can exercise failure cases without touching production data.

If no suitable provider is already connected, prepare a provider-neutral interface and deterministic in-memory test adapter; keep the production adapter absent and the public API disabled until the provider is explicitly selected and configured.

## Remaining release blockers

1. Trusted and fresh B402 `/supported` kind selection, including full object preservation and client override rejection.
2. Durable ledger, idempotency, concurrency control, recovery, and refund logic.
3. Independent settlement receipt/finality verification and reconciliation.
4. Authenticated Alert Shield key directory, freshness/rollback protection, publisher key ceremony, and live-feed tests.
5. Independent assessment of ERC-8004 transfer-away-and-back authorization risk.
6. Read-only BSC fork evidence with `BIP_REQUIRE_LIVE_FORK=1`.
7. Review of all current Slither findings and an independent contract/security review.
8. Privacy, authentication, rate limiting, phishing resistance, operational recovery, and explicit release approval.

## Decision

**NOT READY FOR PRODUCTION.** This follow-up records CI evidence and the next safe implementation unit only. It does not authorize merge, deployment, live settlement, registration, or any state-changing Mainnet transaction.


## Vercel resource discovery result

A read-only Vercel team-context lookup returned the `wadezigh` Hobby team and listed its linked projects, but `bips4444` was not among the projects returned. A project search for `bips4444` in that context returned no match. This does not prove that the project does not exist; it means this session has not established the correct project context or verified a connected database for BIP4444.

**Do not provision a new database or add environment variables based on this incomplete discovery.** First identify the exact existing BIP4444 Vercel project/team context, then inspect its existing storage/connector connections read-only. Do not retrieve decrypted environment-variable values. No database was selected or modified in this audit.
