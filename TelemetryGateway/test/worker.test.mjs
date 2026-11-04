import { test } from "node:test";
import assert from "node:assert/strict";
import worker, { handle } from "../src/worker.mjs";

const event = () => ({
  event: "camera_changed",
  distinct_id: "11111111-2222-4333-8444-555555555555",
  uuid: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
  properties: { app_version: "0.5.0", app_build: "9", distribution: "direct" },
});
const request = (value = event(), headers = {}) => new Request("https://example.test/events", {
  method: "POST", headers: { "Content-Type": "application/json", "CF-Connecting-IP": "192.0.2.1", ...headers },
  body: typeof value === "string" ? value : JSON.stringify(value),
});
const env = (success = true) => ({ POSTHOG_PROJECT_TOKEN: "test-token", RATE_LIMIT_SALT: "test-salt",
  EVENT_RATE_LIMITER: { limit: async ({ key }) => {
    assert.match(key, /^eyeoh:[a-f0-9]{64}$/);
    assert.ok(!key.includes("192.0.2.1"));
    return { success };
  } },
});

test("only the six fixed events and three client properties reach the EU project", async () => {
  for (const name of ["app_launched", "input_changed", "output_changed", "camera_changed", "preview_opened", "feedback_opened"]) {
    const value = event(); value.event = name;
    let called = false;
    const result = await handle(request(value, { Cookie: "private", Authorization: "private", "X-Forwarded-For": "192.0.2.1" }), env(), async (url, options) => {
      called = true;
      assert.equal(url, "https://eu.i.posthog.com/batch/");
      assert.deepEqual(options.headers, { "Content-Type": "application/json" });
      const payload = JSON.parse(options.body);
      assert.equal(payload.api_key, "test-token");
      assert.equal(payload.batch[0].event, name);
      assert.equal(payload.batch[0].properties.$process_person_profile, false);
      assert.equal(payload.batch[0].properties.$geoip_disable, true);
      assert.equal(payload.batch[0].properties.$ip, null);
      assert.ok(!options.body.includes("192.0.2.1"));
      assert.ok(!options.body.includes("private"));
      return new Response(null, { status: 200 });
    });
    assert.equal(result.status, 204); assert.ok(called);
  }
});

test("unknown fields, device data, invalid IDs and unrecognised events are rejected", async () => {
  const bad = [
    { ...event(), device_name: "private" },
    { ...event(), properties: { ...event().properties, device_name: "private" } },
    { ...event(), event: "screen_viewed" },
    { ...event(), distinct_id: "email@example.test" },
    { ...event(), uuid: "not-a-uuid" },
    { ...event(), properties: { ...event().properties, distribution: "source" } },
    { ...event(), properties: { ...event().properties, app_build: "private" } },
    null,
    "not json",
  ];
  for (const value of bad) {
    const result = await handle(request(value), env(), () => assert.fail("must not forward invalid events"));
    assert.equal(result.status, 400);
  }
});

test("rate limiting and missing configuration fail closed", async () => {
  const noSend = () => assert.fail("must not forward");
  assert.equal((await handle(request(), env(false), noSend)).status, 429);
  assert.equal((await handle(request(), {}, noSend)).status, 503);
  assert.equal((await handle(request(), { ...env(), EVENT_RATE_LIMITER: { limit() { throw new Error(); } } }, noSend)).status, 503);
});

test("payload limit applies even when Content-Length is missing or false", async () => {
  for (const headers of [{}, { "Content-Length": "1" }, { "Content-Length": "10000000" }]) {
    assert.equal((await handle(request("x".repeat(2049), headers), env())).status, 413);
  }
});

test("upstream failure returns no provider details or credentials", async () => {
  for (const send of [async () => new Response("secret provider details", { status: 401 }), async () => { throw new Error("private"); }]) {
    const result = await handle(request(), env(), send);
    assert.equal(result.status, 502); assert.equal(await result.text(), "");
    assert.equal(result.headers.get("Cache-Control"), "no-store");
  }
});

test("wrong method, route and content type never invoke the upstream service", async () => {
  const noSend = () => assert.fail("must not forward");
  assert.equal((await handle(new Request("https://example.test/events"), env(), noSend)).status, 405);
  assert.equal((await handle(new Request("https://example.test/events?private=value"), env(), noSend)).status, 404);
  assert.equal((await handle(request(event(), { "Content-Type": "text/plain" }), env(), noSend)).status, 415);
});

test("Worker entry point handles the runtime execution context", async t => {
  let called = false;
  t.mock.method(globalThis, "fetch", async () => { called = true; return new Response(null, { status: 200 }); });
  assert.equal((await worker.fetch(request(), env(), { waitUntil() {} })).status, 204);
  assert.ok(called);
});
