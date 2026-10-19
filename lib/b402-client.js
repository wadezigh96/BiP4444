const crypto = require("node:crypto");

const DEFAULT_TIMEOUT_MS = 10_000;
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
  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    url.search ||
    url.hash
  ) {
    throw new B402Error("B402_CONFIG_INVALID", "B402_BASE_URL must be HTTPS without credentials, query, or fragment.");
  }
  return url.toString().replace(/\/$/, "");
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
    throw new B402Error(
      "B402_CONFIG_MISSING",
      "B402 credentials are not configured. No payment request was sent."
    );
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
    throw new B402Error(
      "B402_KEY_INVALID",
      "B402 signing key must be a valid Base64-encoded PKCS#8 RSA private key."
    );
  }

  async function post(path, payload) {
    if (!["/papi/v2/b402/supported", "/papi/v2/b402/verify", "/papi/v2/b402/settle"].includes(path)) {
      throw new B402Error("B402_PATH_REJECTED", "Unsupported B402 endpoint.");
    }

    const body = JSON.stringify(payload);
    const timestamp = String(now());
    const signature = crypto
      .sign("RSA-SHA256", Buffer.from(body + timestamp, "utf8"), privateKey)
      .toString("base64");

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
      throw new B402Error(
        "B402_TRANSPORT_ERROR",
        "B402 request failed or timed out. Reconcile the operation before retrying."
      );
    }

    if (!response || response.status < 200 || response.status >= 300) {
      throw new B402Error(
        response && response.status >= 300 && response.status < 400
          ? "B402_REDIRECT_REJECTED"
          : "B402_HTTP_ERROR",
        "B402 returned a non-success HTTP status. Sensitive provider details were not exposed."
      );
    }

    let envelope;
    try {
      envelope = await response.json();
    } catch {
      throw new B402Error("B402_RESPONSE_INVALID", "B402 returned invalid JSON.");
    }

    if (
      !envelope ||
      typeof envelope !== "object" ||
      envelope.code !== "000000" ||
      !envelope.data ||
      typeof envelope.data !== "object"
    ) {
      throw new B402Error("B402_PROVIDER_ERROR", "B402 response did not contain a successful data envelope.");
    }

    return envelope.data;
  }

  return Object.freeze({
    getSupported() {
      return post("/papi/v2/b402/supported", {});
    },

    verifyPayment(paymentPayload, paymentRequirements) {
      return post("/papi/v2/b402/verify", {
        x402Version: 2,
        paymentPayload,
        paymentRequirements,
      });
    },

    async settlePayment(paymentPayload, paymentRequirements, verification) {
      // Settlement is irreversible. This adapter stays disabled unless both explicit
      // server-side release switches are set; the API scaffold does not call this method.
      if (env.BIP_ENABLE_LIVE_SETTLEMENT !== "true" || env.BIP_RELEASE_APPROVED !== "true") {
        throw new B402Error(
          "B402_SETTLEMENT_DISABLED",
          "Settlement is disabled until explicit release approval and server-side enablement."
        );
      }
      if (!verification || verification.isValid !== true || typeof verification.payer !== "string") {
        throw new B402Error(
          "B402_VERIFICATION_REQUIRED",
          "A successful B402 verification result is required before settlement."
        );
      }
      return post("/papi/v2/b402/settle", {
        x402Version: 2,
        paymentPayload,
        paymentRequirements,
      });
    },
  });
}

module.exports = {
  B402Error,
  createB402Client,
  REQUIRED_HEADERS,
};
