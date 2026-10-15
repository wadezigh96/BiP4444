import { verifyAccessToken } from "@privy-io/node";

const json = (res, status, body) => {
  res.status(status);
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Content-Type-Options", "nosniff");
  return res.json(body);
};

export default async function handler(req, res) {
  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return json(res, 405, { ok: false, error: "method_not_allowed" });
  }

  const appId = process.env.PRIVY_APP_ID;
  const verificationKey = process.env.PRIVY_VERIFICATION_KEY;

  if (!appId || !verificationKey) {
    return json(res, 503, {
      ok: false,
      error: "auth_not_configured",
      message: "Privy server verification is not configured."
    });
  }

  const authorization = req.headers?.authorization;
  const match = typeof authorization === "string"
    ? authorization.match(/^Bearer\s+([^\s]+)$/i)
    : null;

  if (!match) {
    return json(res, 401, { ok: false, error: "missing_bearer_token" });
  }

  try {
    const claims = await verifyAccessToken({
      access_token: match[1],
      app_id: appId,
      verification_key: verificationKey.replace(/\\n/g, "\n")
    });

    if (!claims?.user_id) {
      return json(res, 401, { ok: false, error: "invalid_access_token" });
    }

    // Return only the minimum identity proof needed by the UI.
    // Never return the token, full claims, emails, phone numbers, or wallet data.
    return json(res, 200, {
      ok: true,
      authenticated: true,
      identity: {
        provider: "privy",
        userId: claims.user_id
      },
      capabilities: {
        passportIssued: false,
        paymentsEnabled: false,
        transactionsEnabled: false
      }
    });
  } catch {
    // Do not echo token contents or verifier errors to callers.
    return json(res, 401, { ok: false, error: "invalid_access_token" });
  }
}
