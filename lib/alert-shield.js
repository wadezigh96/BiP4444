const crypto = require("node:crypto");

const OFFICIAL_DOMAIN = "bips4444.vercel.app";
const SEVERITIES = new Set(["S0", "S1", "S2", "S3", "S4"]);
const MAX_ALERT_LIFETIME_MS = 7 * 24 * 60 * 60 * 1000;
const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;

class AlertShieldError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "AlertShieldError";
    this.code = code;
  }
}

function fail(code, message) {
  throw new AlertShieldError(code, message);
}

function stableStringify(value) {
  if (value === null || typeof value === "string" || typeof value === "boolean") {
    return JSON.stringify(value);
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) fail("ALERT_PAYLOAD_INVALID", "Alert contains a non-finite number.");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return "[" + value.map(stableStringify).join(",") + "]";
  }
  if (typeof value === "object") {
    const keys = Object.keys(value).sort();
    return "{" + keys.map((key) => JSON.stringify(key) + ":" + stableStringify(value[key])).join(",") + "}";
  }
  fail("ALERT_PAYLOAD_INVALID", "Alert contains an unsupported value.");
}

function parseUtcTimestamp(value, field) {
  if (typeof value !== "string" ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z$/.test(value)) {
    fail("ALERT_PAYLOAD_INVALID", field + " must be an ISO-8601 UTC timestamp.");
  }
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) fail("ALERT_PAYLOAD_INVALID", field + " is invalid.");
  return parsed;
}

function validatePayload(payload, nowMs) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    fail("ALERT_PAYLOAD_INVALID", "Alert payload must be an object.");
  }
  if (typeof payload.alertId !== "string" || !/^[A-Za-z0-9._:-]{1,128}$/.test(payload.alertId)) {
    fail("ALERT_PAYLOAD_INVALID", "alertId is missing or invalid.");
  }
  if (!SEVERITIES.has(payload.severity)) {
    fail("ALERT_PAYLOAD_INVALID", "severity must be S0 through S4.");
  }
  if (typeof payload.title !== "string" || payload.title.trim().length < 1 || payload.title.length > 120) {
    fail("ALERT_PAYLOAD_INVALID", "title must contain 1–120 characters.");
  }
  if (typeof payload.summary !== "string" || payload.summary.trim().length < 1 || payload.summary.length > 1000) {
    fail("ALERT_PAYLOAD_INVALID", "summary must contain 1–1000 characters.");
  }
  if (!Array.isArray(payload.guidance) || payload.guidance.length < 1 ||
      payload.guidance.length > 10 ||
      payload.guidance.some((item) => typeof item !== "string" || !item.trim() || item.length > 500)) {
    fail("ALERT_PAYLOAD_INVALID", "guidance must contain 1–10 short text instructions.");
  }
  if (typeof payload.uncertainty !== "string" || !payload.uncertainty.trim() || payload.uncertainty.length > 500) {
    fail("ALERT_PAYLOAD_INVALID", "uncertainty is required and must be at most 500 characters.");
  }
  const scopeValid = (typeof payload.affectedScope === "string" && payload.affectedScope.trim().length > 0 && payload.affectedScope.length <= 300) ||
    (Array.isArray(payload.affectedScope) && payload.affectedScope.length > 0 &&
      payload.affectedScope.length <= 20 && payload.affectedScope.every((item) => typeof item === "string" && item.trim() && item.length <= 120));
  if (!scopeValid) fail("ALERT_PAYLOAD_INVALID", "affectedScope must be a short string or a list of short strings.");
  if (typeof payload.reporterId !== "string" || !/^[A-Za-z0-9._:-]{1,128}$/.test(payload.reporterId)) {
    fail("ALERT_PAYLOAD_INVALID", "reporterId is missing or invalid.");
  }

  const publishedAt = parseUtcTimestamp(payload.publishedAt, "publishedAt");
  const expiresAt = parseUtcTimestamp(payload.expiresAt, "expiresAt");
  if (publishedAt > nowMs + MAX_CLOCK_SKEW_MS) fail("ALERT_NOT_YET_VALID", "Alert publication time is too far in the future.");
  if (expiresAt <= nowMs) fail("ALERT_EXPIRED", "Alert has expired.");
  if (expiresAt <= publishedAt || expiresAt - publishedAt > MAX_ALERT_LIFETIME_MS) {
    fail("ALERT_LIFETIME_INVALID", "Alert expiry must follow publication and be no more than seven days later.");
  }

  if (!Array.isArray(payload.links) || payload.links.length > 10) {
    fail("ALERT_LINKS_INVALID", "links must be an array with at most ten entries.");
  }
  for (const value of payload.links) {
    let url;
    try {
      url = new URL(value);
    } catch {
      fail("ALERT_LINKS_INVALID", "Alert contains an invalid link.");
    }
    if (url.protocol !== "https:" || url.hostname.toLowerCase() !== OFFICIAL_DOMAIN ||
        url.username || url.password || (url.port && url.port !== "443")) {
      fail("ALERT_LINKS_INVALID", "Alert links must use HTTPS on the official BIP4444 domain only.");
    }
  }
  for (const optionalId of ["replacesAlertId", "cancelsAlertId"]) {
    if (payload[optionalId] !== undefined &&
        (typeof payload[optionalId] !== "string" || !/^[A-Za-z0-9._:-]{1,128}$/.test(payload[optionalId]))) {
      fail("ALERT_PAYLOAD_INVALID", optionalId + " is invalid.");
    }
  }
}

function verifyAlert(envelope, keyDirectory, options = {}) {
  const nowMs = options.nowMs === undefined ? Date.now() : options.nowMs;
  if (!envelope || typeof envelope !== "object" || !envelope.payload || !Array.isArray(envelope.signatures)) {
    fail("ALERT_ENVELOPE_INVALID", "Alert envelope must contain payload and signatures.");
  }
  if (!keyDirectory || keyDirectory.version !== 1 || !Array.isArray(keyDirectory.keys) ||
      !Array.isArray(keyDirectory.domainAllowlist) ||
      !keyDirectory.domainAllowlist.includes(OFFICIAL_DOMAIN)) {
    fail("ALERT_KEY_DIRECTORY_INVALID", "Trusted key directory is missing or invalid.");
  }

  validatePayload(envelope.payload, nowMs);
  const message = Buffer.from(stableStringify(envelope.payload), "utf8");
  const keysById = new Map();
  for (const entry of keyDirectory.keys) {
    if (entry && typeof entry.keyId === "string") keysById.set(entry.keyId, entry);
  }

  const validSigners = [];
  const seenKeyIds = new Set();
  for (const signatureEntry of envelope.signatures) {
    if (!signatureEntry || typeof signatureEntry.keyId !== "string" ||
        typeof signatureEntry.signature !== "string" || seenKeyIds.has(signatureEntry.keyId)) continue;
    seenKeyIds.add(signatureEntry.keyId);

    const key = keysById.get(signatureEntry.keyId);
    if (!key || key.status !== "active" || typeof key.reporterId !== "string") continue;
    const validFrom = parseUtcTimestamp(key.validFrom, "key.validFrom");
    const validUntil = parseUtcTimestamp(key.validUntil, "key.validUntil");
    if (nowMs < validFrom || nowMs >= validUntil) continue;
    if (!/^[A-Za-z0-9_-]+={0,2}$/.test(signatureEntry.signature)) continue;

    try {
      const publicKey = crypto.createPublicKey({
        key: Buffer.from(key.publicKey, "base64"),
        format: "der",
        type: "spki",
      });
      if (publicKey.asymmetricKeyType !== "ed25519") continue;
      const signature = Buffer.from(signatureEntry.signature, "base64");
      if (signature.length !== 64) continue;
      if (crypto.verify(null, message, publicKey, signature)) {
        validSigners.push({ keyId: key.keyId, reporterId: key.reporterId });
      }
    } catch {
      // Malformed or unsupported directory entries are not trusted.
    }
  }

  const distinctReporters = new Set(validSigners.map((item) => item.reporterId));
  const hasPrimaryReporter = validSigners.some((item) => item.reporterId === envelope.payload.reporterId);
  const required = ["S3", "S4"].includes(envelope.payload.severity) ? 2 : 1;
  if (!hasPrimaryReporter || validSigners.length < required ||
      (required === 2 && distinctReporters.size < 2)) {
    fail("ALERT_SIGNATURE_INVALID", "Alert needs a valid primary-reporter signature and the required distinct trusted reporters.");
  }

  return {
    valid: true,
    payload: envelope.payload,
    validSigners: validSigners.map((item) => item.keyId),
  };
}

module.exports = {
  AlertShieldError,
  OFFICIAL_DOMAIN,
  stableStringify,
  verifyAlert,
};
