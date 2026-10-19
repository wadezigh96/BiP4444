const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { AlertShieldError, stableStringify, verifyAlert } = require("../lib/alert-shield");

const NOW = Date.parse("2026-10-19T00:00:00Z");
const primary = crypto.generateKeyPairSync("ed25519");
const secondary = crypto.generateKeyPairSync("ed25519");
const revoked = crypto.generateKeyPairSync("ed25519");

function publicKeyBase64(pair) {
  return pair.publicKey.export({ format: "der", type: "spki" }).toString("base64");
}

const directory = {
  version: 1,
  updatedAt: "2026-10-18T00:00:00Z",
  domainAllowlist: ["bips4444.vercel.app"],
  keys: [
    {
      keyId: "ops-2026",
      reporterId: "ops",
      status: "active",
      publicKey: publicKeyBase64(primary),
      validFrom: "2026-01-01T00:00:00Z",
      validUntil: "2027-01-01T00:00:00Z",
    },
    {
      keyId: "security-2026",
      reporterId: "security",
      status: "active",
      publicKey: publicKeyBase64(secondary),
      validFrom: "2026-01-01T00:00:00Z",
      validUntil: "2027-01-01T00:00:00Z",
    },
    {
      keyId: "revoked-2026",
      reporterId: "ops",
      status: "revoked",
      publicKey: publicKeyBase64(revoked),
      validFrom: "2026-01-01T00:00:00Z",
      validUntil: "2027-01-01T00:00:00Z",
    },
  ],
};

function makePayload(overrides = {}) {
  return {
    alertId: "alert-2026-001",
    severity: "S2",
    title: "Security notice",
    summary: "Review your agent's permissions.",
    guidance: ["Open the official BIP4444 website directly.", "Never share a seed phrase."],
    uncertainty: "The investigation is ongoing.",
    affectedScope: ["BSC", "ERC-8004"],
    links: ["https://bips4444.vercel.app/security"],
    publishedAt: "2026-10-18T00:00:00Z",
    expiresAt: "2026-10-20T00:00:00Z",
    reporterId: "ops",
    ...overrides,
  };
}

function sign(payload, keyId, pair) {
  return {
    keyId,
    signature: crypto.sign(null, Buffer.from(stableStringify(payload), "utf8"), pair.privateKey).toString("base64"),
  };
}

function envelope(payload, signers = [["ops-2026", primary]]) {
  return { payload, signatures: signers.map(([keyId, pair]) => sign(payload, keyId, pair)) };
}

function expectCode(fn, code) {
  assert.throws(fn, (error) => error instanceof AlertShieldError && error.code === code);
}

test("verifies a correctly signed low-severity alert", () => {
  const result = verifyAlert(envelope(makePayload()), directory, { nowMs: NOW });
  assert.equal(result.valid, true);
  assert.deepEqual(result.validSigners, ["ops-2026"]);
});

test("canonical JSON makes object key ordering irrelevant", () => {
  const left = { z: 1, a: { y: 2, b: 3 } };
  const right = { a: { b: 3, y: 2 }, z: 1 };
  assert.equal(stableStringify(left), stableStringify(right));
});

test("rejects payload tampering after signing", () => {
  const payload = makePayload();
  const signed = envelope(payload);
  signed.payload.summary = "A changed message.";
  expectCode(() => verifyAlert(signed, directory, { nowMs: NOW }), "ALERT_SIGNATURE_INVALID");
});

test("critical alerts require two distinct trusted reporters", () => {
  const payload = makePayload({ severity: "S4" });
  expectCode(() => verifyAlert(envelope(payload), directory, { nowMs: NOW }), "ALERT_SIGNATURE_INVALID");
  const signed = envelope(payload, [["ops-2026", primary], ["security-2026", secondary]]);
  const result = verifyAlert(signed, directory, { nowMs: NOW });
  assert.equal(result.valid, true);
  assert.equal(result.validSigners.length, 2);
});

test("revoked keys cannot authenticate an alert", () => {
  const payload = makePayload();
  expectCode(
    () => verifyAlert(envelope(payload, [["revoked-2026", revoked]]), directory, { nowMs: NOW }),
    "ALERT_SIGNATURE_INVALID"
  );
});

test("rejects expired alerts", () => {
  const payload = makePayload({ expiresAt: "2026-10-18T23:59:59Z" });
  expectCode(() => verifyAlert(envelope(payload), directory, { nowMs: NOW }), "ALERT_EXPIRED");
});

test("rejects phishing links outside the official HTTPS domain", () => {
  const payload = makePayload({ links: ["https://bips4444-verification.example/login"] });
  expectCode(() => verifyAlert(envelope(payload), directory, { nowMs: NOW }), "ALERT_LINKS_INVALID");
});

test("rejects malformed or untrusted key directories", () => {
  expectCode(
    () => verifyAlert(envelope(makePayload()), { version: 1, keys: [], domainAllowlist: ["evil.example"] }, { nowMs: NOW }),
    "ALERT_KEY_DIRECTORY_INVALID"
  );
});

test("rejects alerts signed by a key outside its validity period", () => {
  const payload = makePayload();
  const expiredDirectory = {
    ...directory,
    keys: directory.keys.map((entry) =>
      entry.keyId === "ops-2026" ? { ...entry, validUntil: "2026-10-18T00:00:00Z" } : entry
    ),
  };
  expectCode(() => verifyAlert(envelope(payload), expiredDirectory, { nowMs: NOW }), "ALERT_SIGNATURE_INVALID");
});
