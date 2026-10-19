const crypto = require("node:crypto");

const DEFAULT_TIMEOUT_MS = 10_000;
const PAYMENT_POLICY = Object.freeze({
  scheme: "exact",
  network: "eip155:56",
  amount: "4000000000000000000",
  asset: "0x55d398326f99059fF775485246999027B3197955",
  payTo: "0xFf265912c76342c8469cE18aB9DF0B2f37d9373c",
});
const REQUIRED_HEADERS = [
  "X-Tesla-ClientId",
  "X-Tesla-SignAccessToken",
  "X-Tesla-Signature",
  "X-Tesla-Timestamp",
];

class B402Error extends Error {
  constructor(code, message) {
    super(message);
    this.name = "B402Error";
    this.code = code;
  }
}

function requireHttpsBaseUrl(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new B402Error("B402_CONFIG_INVALID", "B402_BASE_URL must be a valid HTTPS URL.");
  }
  if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash) {
    throw new B402Error("B402_CONFIG_INVALID", "B402_BASE_URL must be HTTPS without credentials, query, or fragment.");
  }
  return url.toString().replace(/\/$/, "");
}

function canonicalJson(value) {
  if (value === null || typeof value === "string" || typeof value === "boolean") return JSON.stringify(value);
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new B402Error("B402_PAYLOAD_INVALID", "Non-finite JSON number.");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return "[" + value.map(canonicalJson).join(",") + "]";
  if (value && typeof value === "object") {
    return "{" + Object.keys(value).sort().map((key) =>
      JSON.stringify(key) + ":" + canonicalJson(value[key])
    ).join(",") + "}";
  }
  throw new B402Error("B402_PAYLOAD_INVALID", "Unsupported value in B402 payload.");
}

function createB402Client(options = {}) {
  const env = options.env || process.env;
  const fetchImpl = options.fetchImpl || globalThis.fetch;
  const now = options.now || Date.now;
  const timeoutMs = options.timeoutMs || DEFAULT_TIMEOUT_MS;

  if (typeof fetchImpl !== "function") {
    throw new B402Error("B402_FETCH_UNAVAILABLE", "This Node.js runtime does not provide fetch.");
  }

  const baseUrl = requireHttpsBaseUrl(env.B402_BASE_URL || "");
  const clientId = env.B402_CLIENT_ID;
  const accessToken = env.B402_ACCESS_TOKEN;
  const privateKeyBase64 = env.B402_SIGNING_PRIVATE_KEY_BASE64;

  if (!clientId || !accessToken || !privateKeyBase64) {
    throw new B402Error("B402_CONFIG_MISSING", "B402 credentials are not configured. No payment request was sent.");
  }

  let privateKey;
  try {
    privateKey = crypto.createPrivateKey({
      key: Buffer.from(privateKeyBase64, "base64"),
      format: "der",
      type: "pkcs8",
    });
    if (privateKey.asymmetricKeyType !== "rsa") throw new Error("not RSA");
  } catch {
    throw new B402Error("B402_KEY_INVALID", "B402 signing key must be Base64-encoded PKCS#8 RSA.");
  }

  function validateRequirements(requirements) {
    if (!requirements || typeof requirements !== "object") {
      throw new B402Error("B402_REQUIREMENTS_INVALID", "Payment requirements are missing.");
    }
    for (const field of ["scheme", "network", "amount", "asset", "payTo"]) {
      const expected = PAYMENT_POLICY[field];
      const actual = requirements[field];
      const matches = field === "asset" || field === "payTo"
        ? typeof actual === "string" && actual.toLowerCase() === expected.toLowerCase()
        : actual === expected;
      if (!matches) {
        throw new B402Error("B402_REQUIREMENTS_REJECTED", "Payment requirements do not match the locked BIP4444 BSC policy.");
      }
    }
    if (!Number.isInteger(requirements.maxTimeoutSeconds) ||
        requirements.maxTimeoutSeconds < 1 || requirements.maxTimeoutSeconds > 300) {
      throw new B402Error("B402_REQUIREMENTS_REJECTED", "Payment timeout must be between 1 and 300 seconds.");
    }
    const extra = requirements.extra;
    if (!extra || typeof extra !== "object" ||
        typeof extra.name !== "string" || !extra.name ||
        typeof extra.version !== "string" || !extra.version ||
        typeof extra.signerAddress !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(extra.signerAddress)) {
      throw new B402Error("B402_REQUIREMENTS_REJECTED", "B402 supported-kind extra fields are missing or invalid.");
    }
    if (extra.assetTransferMethod === "permit2-exact") {
      if (typeof extra.spenderAddress !== "string" || !/^0x[0-9a-fA-F]{40}$/.test(extra.spenderAddress)) {
        throw new B402Error("B402_REQUIREMENTS_REJECTED", "Permit2 requirements need a valid spenderAddress.");
      }
    } else if (extra.assetTransferMethod === "eip3009") {
      if (extra.spenderAddress != null) {
        throw new B402Error("B402_REQUIREMENTS_REJECTED", "EIP-3009 requirements must not include spenderAddress.");
      }
    } else {
      throw new B402Error("B402_REQUIREMENTS_REJECTED", "Only exact EIP-3009 or Permit2 payment kinds are accepted.");
    }
  }

  function validateAccepted(paymentPayload, requirements) {
    if (!paymentPayload || paymentPayload.x402Version !== 2 ||
        !paymentPayload.accepted || typeof paymentPayload.accepted !== "object") {
      throw new B402Error("B402_PAYLOAD_INVALID", "B402 V2 paymentPayload is missing or malformed.");
    }
    const accepted = paymentPayload.accepted;
    for (const field of ["scheme", "network", "amount", "asset", "payTo", "maxTimeoutSeconds"]) {
      const a = accepted[field];
      const b = requirements[field];
      const matches = field === "asset" || field === "payTo"
        ? typeof a === "string" && a.toLowerCase() === String(b).toLowerCase()
        : a === b;
      if (!matches) {
        throw new B402Error("B402_PAYLOAD_MISMATCH", "Signed payment requirements do not match BIP4444 policy.");
      }
    }
    if (!accepted.extra || typeof accepted.extra !== "object" || Array.isArray(accepted.extra) ||
        canonicalJson(accepted.extra) !== canonicalJson(requirements.extra)) {
      throw new B402Error("B402_PAYLOAD_MISMATCH", "The complete signed B402 extra object must exactly match the supported payment kind.");
    }
  }

  const verifiedPayments = new Map();
  function verificationKey(paymentPayload, paymentRequirements) {
    return crypto.createHash("sha256")
      .update(canonicalJson([paymentPayload, paymentRequirements]))
      .digest("hex");
  }

  async function post(path, payload) {
    if (!["/papi/v2/b402/supported", "/papi/v2/b402/verify", "/papi/v2/b402/settle"].includes(path)) {
      throw new B402Error("B402_PATH_REJECTED", "Unsupported B402 endpoint.");
    }
    const body = JSON.stringify(payload);
    const timestamp = String(now());
    const signature = crypto.sign("RSA-SHA256", Buffer.from(body + timestamp, "utf8"), privateKey).toString("base64");

    let response;
    try {
      response = await fetchImpl(baseUrl + path, {
        method: "POST",
        redirect: "manual",
        signal: AbortSignal.timeout(timeoutMs),
        headers: {
          "Content-Type": "application/json",
          "X-Tesla-ClientId": clientId,
          "X-Tesla-SignAccessToken": accessToken,
          "X-Tesla-Signature": signature,
          "X-Tesla-Timestamp": timestamp,
        },
        body,
      });
    } catch {
      throw new B402Error("B402_TRANSPORT_ERROR", "B402 request failed or timed out. Reconcile before retrying.");
    }

    if (!response || response.status < 200 || response.status >= 300) {
      throw new B402Error(
        response && response.status >= 300 && response.status < 400 ? "B402_REDIRECT_REJECTED" : "B402_HTTP_ERROR",
        "B402 returned a non-success HTTP status. Sensitive provider details were not exposed."
      );
    }

    let envelope;
    try {
      envelope = await response.json();
    } catch {
      throw new B402Error("B402_RESPONSE_INVALID", "B402 returned invalid JSON.");
    }
    if (!envelope || typeof envelope !== "object" || envelope.code !== "000000" ||
        !envelope.data || typeof envelope.data !== "object") {
      throw new B402Error("B402_PROVIDER_ERROR", "B402 response did not contain a successful data envelope.");
    }
    return envelope.data;
  }

  return Object.freeze({
    getSupported() {
      return post("/papi/v2/b402/supported", {});
    },

    async verifyPayment(paymentPayload, paymentRequirements) {
      validateRequirements(paymentRequirements);
      validateAccepted(paymentPayload, paymentRequirements);
      const result = await post("/papi/v2/b402/verify", {
        x402Version: 2,
        paymentPayload,
        paymentRequirements,
      });
      const key = verificationKey(paymentPayload, paymentRequirements);
      if (result.isValid === true && typeof result.payer === "string" &&
          /^0x[0-9a-fA-F]{40}$/.test(result.payer)) {
        verifiedPayments.set(key, result.payer.toLowerCase());
      } else {
        verifiedPayments.delete(key);
      }
      return result;
    },

    async settlePayment(paymentPayload, paymentRequirements) {
      if (env.BIP_ENABLE_LIVE_SETTLEMENT !== "true" || env.BIP_RELEASE_APPROVED !== "true") {
        throw new B402Error("B402_SETTLEMENT_DISABLED", "Settlement is disabled until explicit release approval.");
      }
      validateRequirements(paymentRequirements);
      validateAccepted(paymentPayload, paymentRequirements);
      const key = verificationKey(paymentPayload, paymentRequirements);
      const verifiedPayer = verifiedPayments.get(key);
      if (!verifiedPayer) {
        throw new B402Error("B402_VERIFICATION_REQUIRED", "The same payment must pass verify on this client instance first.");
      }
      verifiedPayments.delete(key);
      const result = await post("/papi/v2/b402/settle", {
        x402Version: 2,
        paymentPayload,
        paymentRequirements,
      });
      if (typeof result.payer !== "string" || result.payer.toLowerCase() !== verifiedPayer) {
        throw new B402Error("B402_PAYER_MISMATCH", "Settlement payer did not match the verified payer.");
      }
      if (result.success !== true || typeof result.transaction !== "string" || !result.transaction) {
        throw new B402Error("B402_SETTLEMENT_NOT_CONFIRMED", "Settlement is not confirmed. Reconcile before retrying or refunding.");
      }
      if (result.network !== PAYMENT_POLICY.network || result.amount !== PAYMENT_POLICY.amount) {
        throw new B402Error("B402_SETTLEMENT_MISMATCH", "Settlement network or amount did not match BIP4444 policy.");
      }
      return result;
    },
  });
}

module.exports = {
  B402Error,
  createB402Client,
  PAYMENT_POLICY,
  REQUIRED_HEADERS,
};
