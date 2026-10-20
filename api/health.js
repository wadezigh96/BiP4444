// BIP4444 API health endpoint.
// This reports implementation status only; it does not verify payments or membership.
module.exports = function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Content-Type", "application/json; charset=utf-8");

  if (req.method !== "GET" && req.method !== "HEAD") {
    res.setHeader("Allow", "GET, HEAD");
    return res.status(405).json({
      ok: false,
      service: "bip4444-api",
      status: "design-only",
      error: { code: "METHOD_NOT_ALLOWED", message: "Use GET.", retryable: false }
    });
  }

  return res.status(200).json({
    ok: true,
    service: "bip4444-api",
    status: "design-only",
    membershipRegistration: "disabled",
    paymentIntegration: "not-configured",
    mainnetTransactionsEnabled: false
  });
};
