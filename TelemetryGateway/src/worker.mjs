const EVENTS = new Set([
  "app_launched", "input_changed", "output_changed", "camera_changed",
  "preview_opened", "feedback_opened",
]);
const MAX_BYTES = 2048;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const response = (status, headers = {}) => new Response(null, {
  status,
  headers: { "Cache-Control": "no-store", "X-Robots-Tag": "noindex", ...headers },
});

function exactKeys(value, keys) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    && Object.keys(value).length === keys.length
    && keys.every(key => Object.hasOwn(value, key));
}

export function validEvent(value) {
  return exactKeys(value, ["event", "distinct_id", "uuid", "properties"])
    && EVENTS.has(value.event)
    && typeof value.distinct_id === "string" && UUID.test(value.distinct_id)
    && typeof value.uuid === "string" && UUID.test(value.uuid)
    && exactKeys(value.properties, ["app_version", "app_build", "distribution"])
    && typeof value.properties.app_version === "string"
    && /^\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(value.properties.app_version)
    && typeof value.properties.app_build === "string"
    && /^\d{1,9}$/.test(value.properties.app_build)
    && ["direct", "mas"].includes(value.properties.distribution);
}

async function boundedJSON(request) {
  if (Number(request.headers.get("Content-Length")) > MAX_BYTES) throw new RangeError();
  if (!request.body) throw new SyntaxError();
  const reader = request.body.getReader();
  const chunks = [];
  let length = 0;
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > MAX_BYTES) {
        await reader.cancel();
        throw new RangeError();
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
}

async function rateLimitKey(request, salt) {
  // Short-lived abuse protection only. Neither raw IPs nor this key enter events or logs.
  const day = new Date().toISOString().slice(0, 10);
  const address = request.headers.get("CF-Connecting-IP") || "unknown";
  const bytes = new TextEncoder().encode(`${salt}:${day}:${address}`);
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return "eyeoh:" + Array.from(hash, byte => byte.toString(16).padStart(2, "0")).join("");
}

export async function handle(request, env, upstreamFetch = fetch) {
  const url = new URL(request.url);
  if (url.pathname !== "/events" || url.search) return response(404);
  if (request.method !== "POST") return response(405, { Allow: "POST" });
  if (!/^application\/json(?:;|$)/i.test(request.headers.get("Content-Type") || "")) return response(415);
  if (!env.POSTHOG_PROJECT_TOKEN || !env.RATE_LIMIT_SALT || !env.EVENT_RATE_LIMITER) return response(503);

  try {
    const { success } = await env.EVENT_RATE_LIMITER.limit({ key: await rateLimitKey(request, env.RATE_LIMIT_SALT) });
    if (!success) return response(429, { "Retry-After": "60" });
  } catch { return response(503); }

  let value;
  try { value = await boundedJSON(request); }
  catch (error) { return response(error instanceof RangeError ? 413 : 400); }
  if (!validEvent(value)) return response(400);

  const timestamp = new Date().toISOString();
  // Rebuild the payload. Never forward client headers, arbitrary fields or caller timestamps.
  const event = {
    event: value.event,
    distinct_id: value.distinct_id,
    uuid: value.uuid,
    timestamp,
    properties: {
      app_version: value.properties.app_version,
      app_build: value.properties.app_build,
      distribution: value.properties.distribution,
      distinct_id: value.distinct_id,
      schema_version: 1,
      $process_person_profile: false,
      $geoip_disable: true,
      $ip: null,
    },
  };
  try {
    const result = await upstreamFetch("https://eu.i.posthog.com/batch/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ api_key: env.POSTHOG_PROJECT_TOKEN, batch: [event], sent_at: timestamp }),
      signal: AbortSignal.timeout(5000),
    });
    return response(result.ok ? 204 : 502);
  } catch { return response(502); }
}

export default { fetch(request, env) { return handle(request, env); } };
