# BIP4444 Alert Shield Specification

**Status:** Verification library and local tests added; publisher/feed still disabled  
**Last updated:** 2026-10-17  
**Official domain (locked):** `bips4444.vercel.app`  
**Key directory URL:** `https://bips4444.vercel.app/.well-known/bip-alert-keys.json`

---

## 1. Purpose

Alert Shield is a **detection and response aid** for BIP members. It publishes signed alerts with severity, guidance, and official links only. It does **not** recover assets or reverse chain transactions.

---

## 2. Official domain & TLS

| Item | Value |
|------|--------|
| Host | **`bips4444.vercel.app`** |
| HTTPS | Provided by **Vercel** (automatic TLS) |
| Key directory | `https://bips4444.vercel.app/.well-known/bip-alert-keys.json` |
| Allowlist | Only this host (and future custom domain if added) in alert `links` |

**Current implementation status:** `lib/alert-shield.js` verifies signed envelopes using Ed25519, a stable canonical JSON representation, active key validity windows, expiry, reporter authorization, and strict HTTPS links to the official host. `test/alert-shield.test.js` covers signatures, tampering, expiry, revoked keys, phishing links, and dual-control severity. The public key directory remains empty, so no publisher is trusted and no live alert feed is enabled. Production HTTP status has not been independently verified.

TLS private keys stay on Vercel — never in git or alert payloads.

---

## 3. Severity (S0–S4)

| Level | Name | Notes |
|-------|------|--------|
| S0 | Info | Single publisher OK |
| S1 | Notice | Single publisher OK |
| S2 | Warning | Single publisher OK |
| S3 | Critical | Requires signatures from two distinct trusted reporters |
| S4 | Emergency | Requires signatures from two distinct trusted reporters |

---

## 4. Alert schema & signed envelope

Payload fields: `alertId`, `severity`, `title`, `summary`, `guidance[]`, `uncertainty`, `affectedScope`, `links[]` (official host only), `publishedAt`, `expiresAt`, `reporterId`, optional `replacesAlertId` / `cancelsAlertId`.

Envelope: `payload` + `signatures[]`, where each signature entry contains `keyId` and a Base64 Ed25519 signature over the canonical JSON payload. Key-directory entries contain `keyId`, `reporterId`, `status` (`active` or `revoked`), Base64 SPKI DER `publicKey`, `validFrom`, and `validUntil`. A valid primary-reporter signature is required for every alert; S3/S4 also require a second signature from a distinct trusted reporter. The verifier rejects expired alerts and links outside the exact official HTTPS hostname.

---

## 5. Key directory format

Served at the official URL above. **Public keys only.**

```json
{
  "version": 1,
  "updatedAt": "2026-10-16T00:00:00Z",
  "keys": [],
  "domainAllowlist": ["bips4444.vercel.app"]
}
```

Add publisher public keys only after offline key generation and independent verification. Rotate via a new `keyId`; revoke compromised keys immediately. Never commit private signing keys. Keep the directory empty until a controlled publisher-key ceremony is completed.

---

## 6. Client verify (short)

1. GET key directory over HTTPS from `bips4444.vercel.app`  
2. Verify each alert signature with active keys  
3. Enforce allowlist on links, expiry, severity caps  
4. Reject unsigned / revoked / revoked-key alerts  

---

## 7. Env vars (names only — values only on Vercel)

See `docs/OPS_ENV.md`. Never put Binance/Privy **secrets** in `NEXT_PUBLIC_*` or client bundles.

---

## 8. Tests before production

- [ ] Key directory 200 + valid JSON on official host  
- [x] Signature / tampering / revoke / expiry / allowlist / dual-control tests passed in GitHub Actions run [39181224188](https://github.com/wadezigh96/BiP4444/actions/runs/39181224188)  
- [x] S3/S4 dual-control enforced by verifier and covered by the passing test suite  

**Security-first:** design + domain locked; feed not live until keys and deploy exist.
