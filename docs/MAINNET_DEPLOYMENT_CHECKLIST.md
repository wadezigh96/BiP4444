# BIP4444 BSC Mainnet Deployment and Release Checklist

**Status:** Runbook only — deployment is not authorized.  
**Target:** BNB Smart Chain Mainnet, chain ID 56 only.  
**Prohibited during this phase:** Testnet transactions, contract deployment, live settlement, and any state-changing Mainnet transaction.

## Preconditions — all must pass

- [ ] Independent reviewer signs off on the exact contract source, constructor parameters, relayer path, and ownership-transfer edge case.
- [ ] CI passes on the exact release commit: API tests, B402 adapter tests, Alert Shield tests, Foundry unit/invariant tests, and reviewed Slither output.
- [ ] A read-only BSC Mainnet fork test passes against the configured ERC-8004 registry and a known valid agent ID.
- [ ] B402 production partner onboarding, base URL, client ID, access token, and RSA signing key are configured server-side. Never commit or paste the private key.
- [ ] Durable database, unique idempotency constraints, reconciliation/outbox jobs, refund runbook, rate limits, and negative payment tests are implemented and independently reviewed.
- [ ] Alert publisher key ceremony and signed key-directory process are complete, or Alert Shield remains clearly disabled.
- [ ] Written release approval is recorded. The public API must remain fail-closed until then.

## Ownership and control sequence

The controller constructor sets owner = msg.sender; it does not automatically assign the Safe as owner. If a future deployment uses a separate deployer, transfer control to the approved 2-of-2 Safe before enabling any relayer or payment flow.

1. Deploy only from an approved release artifact with the ERC-8004 registry constructor argument set to 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432.
2. The initial owner immediately pauses the controller.
3. The initial owner calls transferOwnership(0xFf265912c76342c8469cE18aB9DF0B2f37d9373c).
4. The Safe executes acceptOwnership() on the controller using its 2-of-2 approval policy.
5. Read back and independently verify owner() equals the Safe, pendingOwner() is zero, identityRegistry() equals the approved ERC-8004 registry, MAX_MEMBERS() is 4444, and activeMemberCount() is zero.
6. Keep the controller paused while verifying all settings. Add only the approved relayer address while paused.
7. Enable production payment and unpause only after the API, ledger, B402 settlement reconciliation, refund workflow, and independent review gates have passed.

Do not treat a successful deployment transaction as proof that ownership, registry address, or operational configuration is correct.

## Authorization caveat

ERC-8004 ownership transfers do not notify this controller. The current owner should call invalidateAuthorization(agentId) before transferring an identity if an authorization may be pending. The 15-minute authorization lifetime reduces but does not eliminate the transfer-away-and-back edge case. This limitation must be accepted explicitly by an independent reviewer before release.

## Post-release monitoring

- Reconcile B402 settlement references, chain receipts, registration transaction hashes, and ledger state.
- Alert on ambiguous settlement outcomes, repeated failures, duplicate idempotency conflicts, refund jobs, and active-member count approaching 4444.
- Keep the public API fail-closed if the ledger, facilitator, RPC, or relayer is unhealthy.
- Never log raw payment signatures, private keys, access tokens, or other credentials.
