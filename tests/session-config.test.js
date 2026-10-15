import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../api/session.js", import.meta.url), "utf8");

test("session endpoint uses official Privy access-token verification", () => {
  assert.match(source, /verifyAccessToken/);
  assert.match(source, /@privy-io\/node/);
  assert.match(source, /PRIVY_VERIFICATION_KEY/);
});

test("session endpoint never enables wallet actions or payments", () => {
  assert.match(source, /transactionsEnabled:\s*false/);
  assert.match(source, /paymentsEnabled:\s*false/);
  assert.match(source, /passportIssued:\s*false/);
});

test("session endpoint does not log or return raw bearer token", () => {
  assert.doesNotMatch(source, /console\.(log|error|warn)/);
  assert.match(source, /invalid_access_token/);
  assert.match(source, /missing_bearer_token/);
});
