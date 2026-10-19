const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { B402Error, createB402Client, PAYMENT_POLICY } = require("../lib/b402-client");

const pair = crypto.generateKeyPairSync("rsa", { modulusLength: 1024 });
const privateKeyBase64 = pair.privateKey.export({ type: "pkcs8", format: "der" }).toString("base64");
const PAYER = "0x1111111111111111111111111111111111111111";
const SIGNER = "0x2222222222222222222222222222222222222222";
const SPENDER = "0x3333333333333333333333333333333333333333";

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

function requirements(overrides = {}) {
  return {
    scheme: PAYMENT_POLICY.scheme,
    network: PAYMENT_POLICY.network,
    amount: PAYMENT_POLICY.amount,
    asset: PAYMENT_POLICY.asset,
    payTo: PAYMENT_POLICY.payTo,
    maxTimeoutSeconds: 300,
    extra: {
      name: "Tether USD",
      version: "1",
      assetTransferMethod: "permit2-exact",
      signerAddress: SIGNER,
      spenderAddress: SPENDER,
    },
    ...overrides,
  };
}

function payload(req = requirements(), overrides = {}) {
  return {
    x402Version: 2,
    resource: { url: "https://bips4444.vercel.app/v1/membership/register" },
    accepted: {
      scheme: req.scheme,
      network: req.network,
      amount: req.amount,
      asset: req.asset,
      payTo: req.payTo,
      maxTimeoutSeconds: req.maxTimeoutSeconds,
      extra: { ...req.extra },
    },
    payload: {
      signature: "0x" + "a".repeat(130),
      permit2Authorization: {
        permitted: { token: req.asset, amount: req.amount },
        from: PAYER,
        spender: req.extra.spenderAddress,
        nonce: "1",
        deadline: "1800000000",
        witness: { to: req.payTo, validAfter: "0" },
      },
    },
    ...overrides,
  };
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

  assert.deepEqual(await client.getSupported(), { kinds: [] });
  assert.equal(captured.url, "https://b402.example/papi/v2/b402/supported");
  assert.equal(captured.init.method, "POST");
  assert.equal(captured.init.redirect, "manual");
  assert.equal(captured.init.body, "{}");
  assert.equal(captured.init.headers["X-Tesla-ClientId"], "test-client");
  assert.equal(captured.init.headers["X-Tesla-SignAccessToken"], "test-access-token");
  assert.equal(captured.init.headers["X-Tesla-Timestamp"], "1800000000123");
  assert.equal(crypto.verify(
    "RSA-SHA256",
    Buffer.from(captured.init.body + captured.init.headers["X-Tesla-Timestamp"], "utf8"),
    pair.publicKey,
    Buffer.from(captured.init.headers["X-Tesla-Signature"], "base64")
  ), true);
});

test("sends the documented B402 V2 verify envelope", async () => {
  let captured;
  const req = requirements();
  const payment = payload(req);
  const client = createB402Client({
    env: makeEnv(),
    fetchImpl: async (url, init) => {
      captured = { url, body: JSON.parse(init.body) };
      return jsonResponse({ code: "000000", message: "success", data: { isValid: true, payer: PAYER } });
    },
  });

  const result = await client.verifyPayment(payment, req);
  assert.equal(captured.url, "https://b402.example/papi/v2/b402/verify");
  assert.deepEqual(captured.body, { x402Version: 2, paymentPayload: payment, paymentRequirements: req });
  assert.equal(result.isValid, true);
});

test("rejects wrong amount or recipient before calling B402", async () => {
  let called = false;
  const client = createB402Client({
    env: makeEnv(),
    fetchImpl: async () => { called = true; return jsonResponse({ code: "000000", data: {} }); },
  });
  const bad = requirements({ amount: "5000000000000000000" });
  await assert.rejects(client.verifyPayment(payload(bad), bad), (error) =>
    error instanceof B402Error && error.code === "B402_REQUIREMENTS_REJECTED"
  );
  assert.equal(called, false);
});

test("rejects a signed accepted-requirements mismatch", async () => {
  let called = false;
  const req = requirements();
  const payment = payload(req, { accepted: { ...payload(req).accepted, payTo: "0x4444444444444444444444444444444444444444" } });
  const client = createB402Client({
    env: makeEnv(),
    fetchImpl: async () => { called = true; return jsonResponse({ code: "000000", data: {} }); },
  });
  await assert.rejects(client.verifyPayment(payment, req), (error) =>
    error instanceof B402Error && error.code === "B402_PAYLOAD_MISMATCH"
  );
  assert.equal(called, false);
});

test("rejects changes to any B402 extra field before calling the facilitator", async () => {
  let called = false;
  const req = requirements();
  const payment = payload(req, {
    accepted: {
      ...payload(req).accepted,
      extra: { ...req.extra, unexpectedField: "not-from-supported" },
    },
  });
  const client = createB402Client({
    env: makeEnv(),
    fetchImpl: async () => { called = true; return jsonResponse({ code: "000000", data: {} }); },
  });
  await assert.rejects(client.verifyPayment(payment, req), (error) =>
    error instanceof B402Error && error.code === "B402_PAYLOAD_MISMATCH"
  );
  assert.equal(called, false);
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

test("rejects unsuccessful B402 response envelopes", async () => {
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
  const req = requirements();
  const payment = payload(req);
  const client = createB402Client({
    env: makeEnv(),
    fetchImpl: async () => { called = true; return jsonResponse({ code: "000000", data: {} }); },
  });
  await assert.rejects(client.settlePayment(payment, req), (error) =>
    error instanceof B402Error && error.code === "B402_SETTLEMENT_DISABLED"
  );
  assert.equal(called, false);
});

test("settlement requires the same payment to pass verify on this client", async () => {
  const req = requirements();
  const payment = payload(req);
  const client = createB402Client({
    env: makeEnv({ BIP_ENABLE_LIVE_SETTLEMENT: "true", BIP_RELEASE_APPROVED: "true" }),
    fetchImpl: async () => jsonResponse({ code: "000000", data: { success: true } }),
  });
  await assert.rejects(client.settlePayment(payment, req), (error) =>
    error instanceof B402Error && error.code === "B402_VERIFICATION_REQUIRED"
  );
});

test("settlement verifies payer, chain, amount and transaction result", async () => {
  const req = requirements();
  const payment = payload(req);
  const urls = [];
  const client = createB402Client({
    env: makeEnv({ BIP_ENABLE_LIVE_SETTLEMENT: "true", BIP_RELEASE_APPROVED: "true" }),
    fetchImpl: async (url) => {
      urls.push(url);
      if (url.endsWith("/verify")) {
        return jsonResponse({ code: "000000", data: { isValid: true, payer: PAYER } });
      }
      return jsonResponse({
        code: "000000",
        data: {
          success: true,
          transaction: "0x" + "b".repeat(64),
          payer: PAYER,
          network: "eip155:56",
          amount: PAYMENT_POLICY.amount,
        },
      });
    },
  });

  await client.verifyPayment(payment, req);
  const result = await client.settlePayment(payment, req);
  assert.equal(result.success, true);
  assert.equal(urls.length, 2);
  assert.equal(urls[0].endsWith("/verify"), true);
  assert.equal(urls[1].endsWith("/settle"), true);
});

test("transport errors are sanitized", async () => {
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
