# BIP4444 Alert Shield Specification

**Status:** Foundation implemented (client verification + demo)  
**Last updated:** 2026-10-21  
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

**Payload** (canonical JSON string is what is signed):

```json
{
  "alertId": "string",
  "severity": "S0|S1|S2|S3|S4",
  "title": "string",
  "summary": "string",
  "guidance": ["string"],
  "uncertainty": "string",
  "affectedScope": "string",
  "links": ["https://bips4444.vercel.app/..."],
  "publishedAt": "ISO-8601",
  "expiresAt": "ISO-8601",
  "reporterId": "string",
  "replacesAlertId": "optional",
  "cancelsAlertId": "optional"
}
```

**Envelope**:

```json
{
  "payload": { ... },
  "signatures": [
    { "publicKeyId": "string", "signature": "<base64 Ed25519>" }
  ]
}
```

Clients verify each signature against the key directory before display.

---

## 5. Key directory format

Served at the official URL. **Public keys only.**

```json
{
  "version": 1,
  "updatedAt": "ISO-8601",
  "domainAllowlist": ["bips4444.vercel.app"],
  "keys": [
    {
      "publicKeyId": "string",
      "algorithm": "Ed25519",
      "publicKey": "<base64 raw 32 bytes>",
      "status": "active|revoked",
      "note": "optional"
    }
  ]
}
```

Rotate via new `publicKeyId`; set compromised keys to `"status": "revoked"` immediately.

**Current status:** Demo public key present for foundation testing. Private key was generated offline and **never committed**. Replace before any production use.

---

## 6. Client verification

Implemented in `public/js/alert-verify.js` (Web Crypto Ed25519):

1. GET key directory over HTTPS
2. Verify signatures against keys with `status === "active"`
3. Enforce domain allowlist on `links`
4. Reject expired alerts
5. Warn (do not hard-fail) on S3/S4 with fewer than 2 valid signatures

Demo page: `/alert-demo.html`

---

## 7. Publisher (server)

Example: `scripts/alert-publisher-example.js`

- Reads `ALERT_PUBLISHER_PRIVATE_KEY` from environment (PEM)
- Never commits private keys
- Outputs a signed envelope

---

## 8. Tests before production

- [x] Key directory structure + demo public key
- [x] Client verification module (signature, expiry, allowlist)
- [x] Demo page
- [ ] Live key directory 200 on official host (after Vercel deploy)
- [ ] S3/S4 dual-control hard enforcement (optional)
- [ ] Key rotation / revoke tests
- [ ] Independent review of signing key management

**Security-first:** Foundation is in place. Do not treat the demo key or feed as production until real keys are generated offline, rotated into the directory, and the remaining gates pass.
