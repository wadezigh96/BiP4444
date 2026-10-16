# BIP4444 Alert Shield Specification

**Status:** Design (pre-implementation)  
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

**Repository status (2026-10-17):** A static landing page exists at `public/index.html`, and a placeholder public-key directory exists at `public/.well-known/bip-alert-keys.json`. This directory currently has an empty `keys` array, so no alert publisher key is trusted yet. The production deployment's HTTP status was not independently verified in this audit; verify both URLs after deployment before marking the runtime gate complete.

TLS private keys stay on Vercel — never in git or alert payloads.

---

## 3. Severity (S0–S4)

| Level | Name | Notes |
|-------|------|--------|
| S0 | Info | Single publisher OK |
| S1 | Notice | Single publisher OK |
| S2 | Warning | Single publisher OK |
| S3 | Critical | Dual-control recommended |
| S4 | Emergency | Dual-control recommended |

---

## 4. Alert schema & signed envelope

Payload fields: `alertId`, `severity`, `title`, `summary`, `guidance[]`, `uncertainty`, `affectedScope`, `links[]` (official host only), `publishedAt`, `expiresAt`, `reporterId`, optional `replacesAlertId` / `cancelsAlertId`.

Envelope: `payload` + `signatures[]` (Ed25519 recommended). Clients verify against the key directory before display.

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

Add publisher keys after offline keygen. Rotate via new `publicKeyId`; revoke compromised keys immediately.

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
- [ ] Signature / revoke / expiry / allowlist tests  
- [ ] S3/S4 dual-control if enabled  

**Security-first:** design + domain locked; feed not live until keys and deploy exist.
