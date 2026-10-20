const test = require("node:test");
const assert = require("node:assert/strict");
const health = require("../api/health.js");
const register = require("../api/v1/membership/register.js");

function mockResponse() {
  return {
    statusCode: 200,
    headers: {},
    body: undefined,
    setHeader(name, value) { this.headers[name.toLowerCase()] = value; return this; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; }
  };
}

function invoke(handler, req) {
  const res = mockResponse();
  handler(req, res);
  return res;
}

test("health endpoint reports registration disabled and no mainnet transactions", () => {
  const res = invoke(health, { method: "GET", headers: {} });
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.membershipRegistration, "disabled");
  assert.equal(res.body.mainnetTransactionsEnabled, false);
  assert.equal(res.headers["cache-control"], "no-store");
});

test("health endpoint rejects non-GET requests", () => {
  const res = invoke(health, { method: "POST", headers: {} });
  assert.equal(res.statusCode, 405);
});

test("registration endpoint rejects non-POST requests", () => {
  const res = invoke(register, { method: "GET", headers: {} });
  assert.equal(res.statusCode, 405);
});

test("registration requires JSON content type", () => {
  const res = invoke(register, { method: "POST", headers: {}, body: {} });
  assert.equal(res.statusCode, 415);
});

test("registration rejects malformed body", () => {
  const res = invoke(register, { method: "POST", headers: { "content-type": "application/json" }, body: "{" });
  assert.equal(res.statusCode, 400);
  assert.equal(res.body.error.code, "INVALID_REQUEST");
});

test("registration rejects client-controlled payment fields", () => {
  const res = invoke(register, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: { agentId: "123", role: "research", payTo: "0xattacker" }
  });
  assert.equal(res.statusCode, 400);
});

test("registration rejects invalid uint256 agent IDs and unsafe role strings", () => {
  for (const body of [
    { agentId: "-1", role: "research" },
    { agentId: "0x10", role: "research" },
    { agentId: "0", role: "research" },
    { agentId: "123", role: "<script>" },
    { agentId: "123", role: "x".repeat(65) }
  ]) {
    const res = invoke(register, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body
    });
    assert.equal(res.statusCode, 400);
  }
});

test("valid registration request fails closed without payment or chain side effects", () => {
  const res = invoke(register, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: { agentId: "123", role: "research" }
  });
  assert.equal(res.statusCode, 503);
  assert.equal(res.body.error.code, "REGISTRATION_DISABLED");
  assert.match(res.body.error.message, /No payment was requested or processed/);
});
