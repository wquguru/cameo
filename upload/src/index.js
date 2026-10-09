// Cameo character uploads: POST /submit from the gallery page.
//
// The video is the raw request body; the form fields travel in headers. After Turnstile and
// the daily limits pass, the body is streamed straight into pending/ of the private
// cameo-uploads bucket, which has no public domain (no buffering, so it fits the Workers CPU
// budget), then its "moov" box is
// read back with range requests and checked. A failing file is deleted again. The intake
// workflow later turns pending files into GitHub issues for review; nothing here is public.
//
// Abuse controls, cheapest first: a kill switch (UPLOADS_OPEN), a per-IP burst limiter, a ban
// list, Turnstile bound to this site and action, daily per-IP and site-wide quotas, a cap on
// what waits for review (files and bytes), duplicate rejection by SHA-256, then the file checks.
import { inspectMoov, problems, readBoxHeader } from "./mov.js";

const CATEGORIES = new Set(["animal", "person", "other"]);
const DAY = 24 * 60 * 60;

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const allowed = env.ALLOWED_ORIGINS.split(",").includes(origin);
    const cors = allowed
      ? {
          "Access-Control-Allow-Origin": origin,
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, X-Turnstile, X-Name, X-Author, X-Category, X-Rights",
          "Access-Control-Max-Age": "86400",
          Vary: "Origin",
        }
      : { Vary: "Origin" };
    const reply = (status, body) =>
      new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...cors } });

    const { pathname } = new URL(request.url);
    if (pathname !== "/submit") return reply(404, { error: "not_found" });
    if (request.method === "OPTIONS") return new Response(null, { status: allowed ? 204 : 403, headers: cors });
    if (request.method !== "POST") return reply(405, { error: "method" });
    if (!allowed) return reply(403, { error: "origin" });

    if (env.UPLOADS_OPEN !== "true") return reply(503, { error: "paused" });

    const ip = request.headers.get("CF-Connecting-IP") || "";
    // Best effort: counted per Cloudflare machine, so it trims bursts rather than enforcing exactly.
    const { success: calm } = await env.BURST.limit({ key: ip });
    if (!calm) return reply(429, { error: "slow_down" });
    const visitor = await sha256(ip + env.IP_SALT);
    if (await env.LIMITS.get(`ban:${visitor}`)) return reply(403, { error: "refused" });

    const maxBytes = Number(env.MAX_BYTES);
    const length = Number(request.headers.get("Content-Length") || 0);
    if (!length) return reply(411, { error: "length" });
    if (length > maxBytes) return reply(413, { error: "too_large" });

    // Form fields.
    const field = (name, max) => {
      try {
        return decodeURIComponent(request.headers.get(name) || "").trim().slice(0, max);
      } catch {
        return "";
      }
    };
    const name = field("X-Name", 60);
    const author = field("X-Author", 60);
    const category = field("X-Category", 10);
    if (!name || !author || !CATEGORIES.has(category) || request.headers.get("X-Rights") !== "yes") {
      return reply(400, { error: "fields" });
    }

    // Turnstile: one token per upload, issued on the gallery for the "upload" action.
    const verdict = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      body: new URLSearchParams({ secret: env.TURNSTILE_SECRET, response: request.headers.get("X-Turnstile") || "", remoteip: ip }),
    }).then((r) => r.json()).catch(() => ({ success: false }));
    if (!verdict.success || verdict.action !== "upload" || verdict.hostname !== env.TURNSTILE_HOSTNAME) {
      return reply(403, { error: "captcha" });
    }

    // Daily limits, per visitor (hashed IP, never stored in the clear) and for everyone.
    const today = new Date().toISOString().slice(0, 10);
    const ipKey = `ip:${today}:${visitor}`;
    const allKey = `all:${today}`;
    const [ipCount, allCount] = (await Promise.all([env.LIMITS.get(ipKey), env.LIMITS.get(allKey)])).map((v) => Number(v || 0));
    if (ipCount >= Number(env.DAILY_PER_IP)) return reply(429, { error: "limit_you" });
    if (allCount >= Number(env.DAILY_TOTAL)) return reply(429, { error: "limit_all" });

    // Everything waiting for review must stay small.
    const queued = await queueSize(env.BUCKET);
    if (queued.files >= Number(env.QUEUE_MAX_FILES) || queued.bytes + length > Number(env.QUEUE_MAX_BYTES)) {
      return reply(503, { error: "queue_full" });
    }

    // Stream into the private pending/ prefix.
    const id = crypto.randomUUID();
    const key = `pending/${id}.mov`;
    const { readable, writable } = new FixedLengthStream(length);
    const [toBucket, toDigest] = request.body.tee();
    const digest = new crypto.DigestStream("SHA-256");
    const piping = Promise.all([toBucket.pipeTo(writable), toDigest.pipeTo(digest)]).catch(() => {});
    try {
      await env.BUCKET.put(key, readable, {
        httpMetadata: { contentType: "video/quicktime" },
        customMetadata: {
          name: encodeURIComponent(name), author: encodeURIComponent(author), category,
          uploader: visitor, submitted: new Date().toISOString(),
        },
      });
      await piping;
    } catch {
      return reply(400, { error: "upload" });
    }

    // The same file twice is refused.
    const fingerprint = [...new Uint8Array(await digest.digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
    if (await env.LIMITS.get(`sha:${fingerprint}`)) {
      await env.BUCKET.delete(key);
      return reply(409, { error: "duplicate" });
    }

    // Check it; delete what fails.
    let info;
    try {
      info = await inspectStored(env.BUCKET, key, length);
    } catch {
      await env.BUCKET.delete(key);
      return reply(422, { error: "invalid", problems: ["not_mov"] });
    }
    const found = problems(info, length);
    if (found.length) {
      await env.BUCKET.delete(key);
      return reply(422, { error: "invalid", problems: found, info });
    }

    await Promise.all([
      env.LIMITS.put(ipKey, String(ipCount + 1), { expirationTtl: 2 * DAY }),
      env.LIMITS.put(allKey, String(allCount + 1), { expirationTtl: 2 * DAY }),
      env.LIMITS.put(`sha:${fingerprint}`, id, { expirationTtl: 30 * DAY }),
    ]);
    return reply(200, { ok: true, id, info });
  },
};

async function sha256(text) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 32);
}

/// Files and bytes waiting in pending/ and submitted/.
async function queueSize(bucket) {
  let files = 0, bytes = 0;
  for (const prefix of ["pending/", "submitted/"]) {
    let cursor;
    do {
      const page = await bucket.list({ prefix, cursor });
      for (const object of page.objects) { files++; bytes += object.size; }
      cursor = page.truncated ? page.cursor : undefined;
    } while (cursor);
  }
  return { files, bytes };
}

async function range(bucket, key, offset, length) {
  const object = await bucket.get(key, { range: { offset, length } });
  return new Uint8Array(await object.arrayBuffer());
}

/// Walks the top-level boxes with small range reads, then parses the "moov" box.
async function inspectStored(bucket, key, total) {
  let offset = 0;
  for (let step = 0; step < 64 && offset + 8 <= total; step++) {
    const head = await range(bucket, key, offset, Math.min(16, total - offset));
    const box = readBoxHeader(head, 0, total - offset);
    if (!box) break;
    if (box.type === "moov") {
      if (box.size > 8 * 1024 * 1024) throw new Error("moov_too_large");
      return inspectMoov(await range(bucket, key, offset, box.size));
    }
    offset += box.size;
  }
  throw new Error("not_mov");
}
