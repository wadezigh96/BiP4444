const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { B402Error, createB402Client } = require("../lib/b402-client");

const pair = crypto.generateKeyPairSync("rsa", { modulusLength: 1024 });
const privateKeyBase64 = pair.privateKey
  .export({ type: "pkcs8", format: "der" })
  .toString("base64");

function makeEnv(overrides = {}) {
  return {
    B402_BASE_URL: "https://b402.example/",
    B402_CLIENT_ID: "test-client",
    B402_ACCESS_TOKEN: "test-access-token",
    B402_SIGNING_PRIVATE_KEY_BASE64: privateKeyBase64,
    ...overrides,
  };
}

function jsonResponse(data, status = 200) {
  return { status, json: async () => data };
}

test("fails closed when B402 credentials are missing", () => {
  assert.throws(
    () => createB402Client({ env: { B402_BASE_URL: "https://b402.example" } }),
    (error) => error instanceof B402Error && error.code === "B402_CONFIG_MISSING"
  );
});

test("rejects non-HTTPS B402 base URLs", () => {
  assert.throws(
    () => createB402Client({ env: makeEnv({ B402_BASE_URL: "http://b402.example" }) }),
    (error) => error instanceof B402Error && error.code === "B402_CONFIG_INVALID"
  );
});

test("signs the exact JSON body concatenated with the millisecond timestamp", async () => {
  let captured;
  const client = createB402Client({
    env: makeEnv(),
    now: () => 1_800_000_000_123,
    fetchImpl: async (url, init) => {
      captured = { url, init };
      return jsonResponse({ code: "000000", message: "success", data: { kinds: [] } });
    },
  });

  const result = await client.getSupported();
  assert.deepEqual(result, { kinds: [] });
  assert.equal(captured.url, "https://b402.example/papi/v2/b402/supported");
  assert.equal(captured.init.method, "POST");
  assert.equal(captured.init.redirect, "manual");
  assert.equal(captured.init.body, "{}");
  assert.equal(captured.init.headers["X-Tesla-ClientId"], "test-client");
  assert.equal(captured.init.headers["X-Tesla-SignAccessToken"], "test-access-token");
  assert.equal(captured.init.headers["X-Tesla-Timestamp"], "1800000000123");

  const verified = crypto.verify(
    "RSA-SHA256",
    Buffer.from(captured.init.body + captured.init.headers["X-Tesla-Timestamp"], "utf8"),
    pair.publicKey,
    Buffer.from(captured.init.headers["X-Tesla-Signature"], "base64")
  );
  assert.equal(verified, true);
});

test("sends the B402 V2 verify envelope and returns its data", async () => {
  let captured;
  const paymentPayload = { x402Version: 2, accepted: { scheme: "exact" }, payload: { signature: "0xabc" } };
  const paymentRequirements = { scheme: "exact", network: "eip155:56", amount: "4000000000000000000" };
  const client = createB402Client({
    env: makeEnv(),
    fetchImpl: async (url, init) => {
      captured = { url, body: JSON.parse(init.body) };
      return jsonResponse({ code: "000000", message: "success", data: { isValid: true, payer: "0x1111111111111111111111111111111111111111" } });
    },
  });

  const result = await client.verifyPayment(paymentPayload, paymentRequirements);
  assert.equal(captured.url, "https://b402.example/papi/v2/b402/verify");
  assert.deepEqual(captured.body, { x402Version: 2, paymentPayload, paymentRequirements });
  assert.equal(result.isValid, true);
});

test("rejects a redirect instead of forwarding signed credentials", async () => {
  const client = createB402Client({
    env: makeEnv(),
    fetchImpl: async () => ({ status: 302, json: async () => ({}) }),
  });
  await assert.rejects(client.getSupported(), (error) =>
    error instanceof B402Error && error.code === "B402_REDIRECT_REJECTED"
  );
});

test("rejects malformed or unsuccessful B402 response envelopes", async () => {
  const client = createB402Client({
    env: makeEnv(),
    fetchImpl: async () => jsonResponse({ code: "123456", message: "provider error" }),
  });
  await assert.rejects(client.getSupported(), (error) =>
    error instanceof B402Error && error.code === "B402_PROVIDER_ERROR"
  );
});

test("settlement remains disabled without both explicit release switches", async () => {
  let called = false;
  const client = createB402Client({
    env: makeEnv(),
    fetchImpl: async () => {
      called = true;
      return jsonResponse({ code: "000000", data: { success: true } });
    },
  });
  await assert.rejects(
    client.settlePayment({}, {}, { isValid: true, payer: "0x1111111111111111111111111111111111111111" }),
    (error) => error instanceof B402Error && error.code === "B402_SETTLEMENT_DISABLED"
  );
  assert.equal(called, false);
});

test("settlement refuses to run without a successful verification result", async () => {
  const client = createB402Client({
    env: makeEnv({ BIP_ENABLE_LIVE_SETTLEMENT: "true", BIP_RELEASE_APPROVED: "true" }),
    fetchImpl: async () => jsonResponse({ code: "000000", data: { success: true } }),
  });
  await assert.rejects(
    client.settlePayment({}, {}, { isValid: false, payer: "0x1111111111111111111111111111111111111111" }),
    (error) => error instanceof B402Error && error.code === "B402_VERIFICATION_REQUIRED"
  );
});

test("transport errors are sanitized and do not expose provider or secret data", async () => {
  const client = createB402Client({
    env: makeEnv(),
    fetchImpl: async () => { throw new Error("sensitive internal transport detail"); },
  });
  await assert.rejects(client.getSupported(), (error) => {
    assert.equal(error.code, "B402_TRANSPORT_ERROR");
    assert.equal(error.message.includes("sensitive internal"), false);
    assert.equal(error.message.includes("test-access-token"), false);
    return true;
  });
});
