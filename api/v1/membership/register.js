// BIP4444 registration scaffold.
// Deliberately performs no payment verification, database writes, signing, or chain calls.
// Do not enable registration until B402, durable idempotency, and security tests are complete.
const UINT256_MAX = (1n << 256n) - 1n;
const ALLOWED_ROLE = /^[A-Za-z0-9._:-]+$/;
const FORBIDDEN_FIELDS = new Set([
  "payTo", "amount", "asset", "chainId", "network", "facilitator",
  "owner", "paymentId", "transactionHash"
]);

function reply(res, status, code, message, retryable) {
  return res.status(status).json({
    error: { code, message, retryable }
  });
}

function parseBody(body) {
  if (body && typeof body === "object" && !Array.isArray(body)) return body;
  if (typeof body === "string") {
    try {
      const parsed = JSON.parse(body);
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : null;
    } catch (_) {
      return null;
    }
  }
  return null;
}

function validate(body) {
  if (!body || Object.keys(body).some((key) => FORBIDDEN_FIELDS.has(key))) return false;
  if (Object.keys(body).some((key) => key !== "agentId" && key !== "role")) return false;

  if (typeof body.agentId !== "string" || !/^[0-9]+$/.test(body.agentId)) return false;
  try {
    const id = BigInt(body.agentId);
    if (id <= 0n || id > UINT256_MAX) return false;
  } catch (_) {
    return false;
  }

  if (typeof body.role !== "string") return false;
  const role = body.role.trim();
  if (role.length === 0 || Buffer.byteLength(role, "utf8") > 64 || !ALLOWED_ROLE.test(role)) return false;
  return true;
}

module.exports = function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Content-Type", "application/json; charset=utf-8");

  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return reply(res, 405, "METHOD_NOT_ALLOWED", "Use POST.", false);
  }

  const contentType = String((req.headers && req.headers["content-type"]) || "").toLowerCase();
  if (!contentType.startsWith("application/json")) {
    return reply(res, 415, "UNSUPPORTED_MEDIA_TYPE", "Send application/json.", false);
  }

  const body = parseBody(req.body);
  if (!validate(body)) {
    return reply(res, 400, "INVALID_REQUEST", "The request is invalid.", false);
  }

  // Fail closed until a documented B402 adapter, durable ledger, owner-consent
  // flow, and independently tested relayer are implemented.
  return reply(
    res,
    503,
    "REGISTRATION_DISABLED",
    "Membership registration is not enabled. No payment was requested or processed.",
    true
  );
};
