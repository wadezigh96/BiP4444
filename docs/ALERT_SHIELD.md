# BIP4444 Alert Shield Specification

**Status:** Design (pre-implementation)  
**Last updated:** 2026-10-16  
**Audience:** BIP members (operators of ERC-8004 agents on BSC)

---

## 1. Purpose

Alert Shield is a **detection and response aid** for BIP members. It:

1. Ingests configured, documented risk signals and trusted incident sources.
2. Publishes alerts with **verifiable provenance**, timestamps, severity, and mitigation guidance.
3. Directs members to **official** response instructions and verified links only.
4. States uncertainty and possible **false positives** on every alert.

### Out of scope (explicit)

- No guarantee of immunity from attacks  
- Does not block or reverse chain transactions  
- Does not auto-recover assets  
- Does not replace endpoint security, key hygiene, or professional IR  

---

## 2. Design principles

| Principle | Rule |
|-----------|------|
| Authenticity | Every public alert is **signed**; unsigned feeds are not authoritative |
| Least privilege | Reporter keys ≠ fee Safe ≠ relayer |
| Official links only | `https://` on BIP allowlisted domains; no arbitrary URLs in v1 |
| Fail safe | If signature invalid / key revoked → drop alert |
| Privacy | No seed phrases; minimize PII; QR is verification link only |
| Rate limit | Public read + publish paths limited against spam/DoS |

---

## 3. Severity taxonomy

| Level | Name | Meaning | Member expectation |
|-------|------|---------|-------------------|
| **S0** | Info | FYI, no immediate action | Optional read |
| **S1** | Notice | Elevated risk or rumor with low confidence | Monitor; verify sources |
| **S2** | Warning | Credible risk to agents/wallets/protocols BIP cares about | Follow guidance; tighten ops |
| **S3** | Critical | Active exploit / confirmed incident affecting members | Act on rescue steps immediately |
| **S4** | Emergency | Systemic or ongoing attack; max urgency | Full IR mode; official channels only |

### Escalation rules (v1)

- Only **authorized publishers** may emit S2–S4.  
- S3/S4 require **dual control**: two publisher signatures **or** one publisher + one admin co-sign (choose one model at implement time; default recommendation: **2-of-N publisher threshold for S3+**).  
- S0–S1 may be single publisher.  
- Downgrade/cancel must be a new signed message referencing `replacesAlertId` / `cancelsAlertId`.

---

## 4. Alert schema (canonical JSON)

```json
{
  "alertId": "bip-2026-10-16-001",
  "schemaVersion": 1,
  "severity": "S2",
  "title": "Short human title",
  "summary": "What is happening in plain language.",
  "guidance": [
    "Step 1 actionable",
    "Step 2 actionable"
  ],
  "uncertainty": "Confidence and false-positive notes.",
  "affectedScope": {
    "networks": ["eip155:56"],
    "protocols": [],
    "agentIds": [],
    "roles": []
  },
  "links": [
    {
      "label": "Official advisory",
      "url": "https://<official-bip-domain>/alerts/bip-2026-10-16-001"
    }
  ],
  "publishedAt": "2026-10-16T00:00:00Z",
  "expiresAt": "2026-10-17T00:00:00Z",
  "reporterId": "pub-01",
  "replacesAlertId": null,
  "cancelsAlertId": null
}
```

### Field rules

| Field | Rules |
|-------|--------|
| `alertId` | Unique, stable, URL-safe |
| `severity` | One of S0–S4 |
| `links[].url` | Must match allowlisted official host(s) |
| `expiresAt` | Required for S2+; clients should hide/ignore after expiry unless renewed |
| `affectedScope` | Optional filters; empty = broad advisory |
| `guidance` | Actionable; no “send funds to …” unless official BIP domain confirms |

### Envelope (signed)

```json
{
  "payload": { /* alert object above */ },
  "signatures": [
    {
      "reporterId": "pub-01",
      "alg": "ed25519",
      "publicKeyId": "pub-01-key-2026-10",
      "signature": "<base64>",
      "signedAt": "2026-10-16T00:00:00Z"
    }
  ]
}
```

**Signing input:** canonical JSON of `payload` (UTF-8, deterministic key order) or EIP-712 typed data equivalent. Pick **one** stack at implementation:

| Option | Use when |
|--------|----------|
| **Ed25519** (recommended default for feed API) | Off-chain feed, fast verify in any backend/agent |
| **EIP-712 (secp256k1)** | Want wallet-native tooling / on-chain verify later |

v1 recommendation: **Ed25519** for the HTTPS feed; optional later mirror of hash on-chain.

---

## 5. Publishers (reporters) and roles

| Role | Can publish | Notes |
|------|-------------|--------|
| `publisher` | S0–S2 alone; S3–S4 per threshold policy | Operational IR |
| `admin` | Key ceremony, revoke, allowlist domains | Not for routine alerts unless dual-control |
| `viewer` | Read only | Members / public |

### Onboarding a publisher

1. Generate key offline (Ed25519 recommended).  
2. Admin records `reporterId`, `publicKeyId`, pubkey, allowed max severity.  
3. Publish **key directory** on official domain (see §6).  
4. Test sign + verify in staging.  
5. Activate.

### Offboarding / compromise

1. Admin marks `publicKeyId` **revoked** in key directory with `revokedAt`.  
2. Clients **must reject** signatures from revoked keys.  
3. Re-issue alerts if needed under new key (`replacesAlertId`).  
4. Incident note on official domain.

Publishers **never** hold: user seeds, B402 secrets, Safe sole control, or membership relayer keys.

---

## 6. Key directory and rotation

### Key directory (official HTTPS)

Example path: `https://<official-bip-domain>/.well-known/bip-alert-keys.json`

```json
{
  "version": 1,
  "updatedAt": "2026-10-16T00:00:00Z",
  "keys": [
    {
      "reporterId": "pub-01",
      "publicKeyId": "pub-01-key-2026-10",
      "alg": "ed25519",
      "publicKey": "<base64>",
      "maxSeverity": "S4",
      "status": "active",
      "validFrom": "2026-10-01T00:00:00Z",
      "validTo": null,
      "revokedAt": null
    }
  ],
  "domainAllowlist": ["<official-bip-domain>"]
}
```

Directory itself should be served over TLS; optional: sign directory with an **offline root** key kept offline (ceremony documented in runbook).

### Rotation procedure

| Step | Action |
|------|--------|
| 1 | Generate new keypair; new `publicKeyId` |
| 2 | Add to directory as `active` with `validFrom` in the future (overlap window) |
| 3 | Publish test S0 alert with new key |
| 4 | Switch routine publishing to new key |
| 5 | Set old key `status=retired` or `revoked`; set `validTo` |
| 6 | Clients refresh directory at least every **T** minutes (e.g. 15) and on verify failure |

**Emergency revoke:** skip overlap; revoke immediately; notify members via official domain + last-known-good channel.

---

## 7. Storage and delivery

### v1 default: off-chain signed feed

| Component | Role |
|-----------|------|
| Origin API | `GET /v1/alerts`, `GET /v1/alerts/{alertId}` |
| Integrity | Ed25519 (or EIP-712) signatures + key directory |
| History | Server DB; public list may be paginated |
| On-chain | Optional later: emit `alertId` + content hash only |

### Member channels

| Channel | v1 |
|---------|-----|
| Passport / member UI | Poll or SSE official API |
| Webhook (optional) | Member-configured HTTPS URL; signed body; rate-limited |
| Email/Telegram | Out of band; not sole authenticity source |

### Public read API (shape)

```http
GET /v1/alerts?minSeverity=S2&active=true
GET /v1/alerts/{alertId}
```

Response includes full signed envelope. Clients verify signature against key directory before display.

### Publish API (backend only)

```http
POST /v1/admin/alerts
Authorization: publisher credential (not user wallet seed)
```

Not exposed without auth. Body = payload; server attaches/forwards signature or accepts pre-signed envelope.

---

## 8. Client verification algorithm

1. Fetch key directory (cache with TTL; hard-fail if TLS/domain wrong).  
2. Parse envelope; load `payload` + `signatures`.  
3. For required threshold: each sig → resolve `publicKeyId` → status active, not expired, `maxSeverity` ≥ alert severity.  
4. Verify signature over canonical payload.  
5. Check `links` against `domainAllowlist`.  
6. Honor `expiresAt`, `cancelsAlertId`, `replacesAlertId`.  
7. Only then show in UI.

Reject otherwise (do not “show unsigned for convenience”).

---

## 9. Phishing and abuse resistance

- Official domain allowlist only in alert links.  
- QR codes (if any) encode **HTTPS URL to official alert page**, not secrets.  
- Rate-limit `GET` and especially publish paths.  
- Replay: `alertId` unique; clients ignore duplicate ids.  
- Never instruct users to enter seed phrases in guidance text.  
- S3/S4 dual-control reduces single compromised publisher impact.

---

## 10. Relationship to membership

- Alerts may target `roles` or `agentIds` in `affectedScope` (from registration ledger).  
- Non-members may read public alerts; membership is not a secrecy boundary for S2+ advisories that are public by nature.  
- Membership does **not** imply faster chain finality or automatic protection.

---

## 11. Testing requirements (audit gate)

- [ ] Valid signature accepted; tampered payload rejected  
- [ ] Revoked key rejected  
- [ ] Severity above key’s `maxSeverity` rejected  
- [ ] S3/S4 threshold enforced  
- [ ] Expired alert hidden/ignored  
- [ ] Non-allowlisted link rejected  
- [ ] Replay / duplicate `alertId` safe  
- [ ] Key rotation overlap and emergency revoke drilled  
- [ ] Rate-limit behaviour documented  
- [ ] Phishing copy review (no seed requests)  

---

## 12. Implementation checklist

- [ ] Choose Ed25519 vs EIP-712 and document canonical bytes  
- [ ] Key directory on official domain  
- [ ] Publisher onboarding runbook  
- [ ] `GET /v1/alerts` + verify library for UI/agents  
- [ ] Admin publish path  
- [ ] Dual-control for S3/S4  
- [ ] Tests in §11  

---

## 13. Open decisions (minor)

1. Exact **official domain** hostname for allowlist + well-known keys.  
2. Confirm **2-of-N** vs admin co-sign for S3/S4.  
3. Whether to anchor alert hashes on BSC (v2).  

---

**Security-first:** design only. No production alert feed until keys, domain allowlist, and §11 tests are in place.
