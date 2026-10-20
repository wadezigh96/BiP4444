/**
 * BIP4444 Alert Shield — client-side verification (Web Crypto Ed25519)
 *
 * Usage:
 *   import { verifyAlert, fetchKeyDirectory } from './js/alert-verify.js';
 *   const result = await verifyAlert(envelope, keysUrl);
 *
 * Envelope format:
 * {
 *   payload: { alertId, severity, title, summary, guidance, ... },
 *   signatures: [ { publicKeyId, signature: "<base64>" } ]
 * }
 *
 * Security notes:
 * - Only trusts keys with status === "active"
 * - Enforces domain allowlist on links
 * - Rejects expired alerts
 * - S3/S4 dual-control is recommended but not hard-enforced in this foundation
 */

const DEFAULT_KEYS_URL = "/.well-known/bip-alert-keys.json";

export async function fetchKeyDirectory(url = DEFAULT_KEYS_URL) {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error(`Key directory fetch failed: ${res.status}`);
  const dir = await res.json();
  if (!dir.keys || !Array.isArray(dir.keys)) throw new Error("Invalid key directory");
  return dir;
}

function base64ToBytes(b64) {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

async function importEd25519PublicKey(rawB64) {
  const raw = base64ToBytes(rawB64);
  if (raw.length !== 32) throw new Error("Ed25519 public key must be 32 bytes");
  return crypto.subtle.importKey(
    "raw",
    raw,
    { name: "Ed25519" },
    false,
    ["verify"]
  );
}

function canonicalPayload(payload) {
  // Stable stringify for signing (sorted keys not required if publisher uses same JSON.stringify)
  return JSON.stringify(payload);
}

function isExpired(expiresAt) {
  if (!expiresAt) return false;
  return Date.now() > new Date(expiresAt).getTime();
}

function checkLinks(payload, allowlist) {
  if (!payload.links || !Array.isArray(payload.links)) return true;
  for (const link of payload.links) {
    try {
      const host = new URL(link).hostname;
      if (!allowlist.includes(host)) return false;
    } catch {
      return false;
    }
  }
  return true;
}

/**
 * Verify a signed alert envelope.
 * @returns {Promise<{ok: boolean, reason?: string, severity?: string, dualControl?: boolean}>}
 */
export async function verifyAlert(envelope, keysUrl = DEFAULT_KEYS_URL) {
  if (!envelope || !envelope.payload || !Array.isArray(envelope.signatures)) {
    return { ok: false, reason: "Invalid envelope" };
  }

  const dir = await fetchKeyDirectory(keysUrl);
  const activeKeys = new Map(
    dir.keys
      .filter((k) => k.status === "active" && k.algorithm === "Ed25519")
      .map((k) => [k.publicKeyId, k])
  );

  if (activeKeys.size === 0) {
    return { ok: false, reason: "No active keys in directory" };
  }

  const payload = envelope.payload;
  const payloadBytes = new TextEncoder().encode(canonicalPayload(payload));

  // Verify at least one valid signature against an active key
  let validSigCount = 0;
  const verifiedKeyIds = [];

  for (const sigEntry of envelope.signatures) {
    const keyMeta = activeKeys.get(sigEntry.publicKeyId);
    if (!keyMeta) continue;

    try {
      const pubKey = await importEd25519PublicKey(keyMeta.publicKey);
      const sigBytes = base64ToBytes(sigEntry.signature);
      const valid = await crypto.subtle.verify(
        { name: "Ed25519" },
        pubKey,
        sigBytes,
        payloadBytes
      );
      if (valid) {
        validSigCount++;
        verifiedKeyIds.push(sigEntry.publicKeyId);
      }
    } catch {
      // invalid key or signature format — skip
    }
  }

  if (validSigCount === 0) {
    return { ok: false, reason: "No valid signature from active key" };
  }

  if (isExpired(payload.expiresAt)) {
    return { ok: false, reason: "Alert expired", severity: payload.severity };
  }

  const allowlist = dir.domainAllowlist || [];
  if (!checkLinks(payload, allowlist)) {
    return { ok: false, reason: "Link outside domain allowlist", severity: payload.severity };
  }

  const severity = payload.severity || "S0";
  const dualControl = severity === "S3" || severity === "S4";
  const dualControlOk = !dualControl || validSigCount >= 2;

  return {
    ok: true,
    severity,
    dualControl,
    dualControlOk,
    verifiedKeyIds,
    warning: dualControl && !dualControlOk ? "S3/S4 recommends dual-control (2 signatures)" : undefined,
  };
}

/**
 * Convenience: verify and return human-readable result.
 */
export async function verifyAlertDetailed(envelope, keysUrl = DEFAULT_KEYS_URL) {
  const result = await verifyAlert(envelope, keysUrl);
  if (!result.ok) return result;
  return {
    ...result,
    display: {
      title: envelope.payload.title,
      summary: envelope.payload.summary,
      severity: result.severity,
      guidance: envelope.payload.guidance || [],
    },
  };
}
