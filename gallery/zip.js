// Reads what the gallery needs from a character package submitted as a .zip (docs/package-spec.md):
// the table of contents (the zip's central directory) and, on the gallery page, the manifest and
// clips themselves. The same rules as scripts/character_package.py, which unpacks it for review.
// Shared by the upload Worker and the gallery page: edit upload/src/zip.js and copy it to gallery/zip.js.
import { inspectFile } from "./mov.js";

const MAX_FILES = 64;
const MAX_UNPACKED = 200 * 1024 * 1024;
const u16 = (b, p) => b[p] | (b[p + 1] << 8);
const u32 = (b, p) => (b[p] | (b[p + 1] << 8) | (b[p + 2] << 16) | (b[p + 3] << 24)) >>> 0;

/// Looks for the end-of-central-directory record in the last bytes of the file (`tail` ends where
/// the file ends; 64 KB + 22 bytes always holds it). Returns where the central directory is.
export function findDirectory(tail, total) {
  for (let i = tail.length - 22; i >= 0; i--) {
    if (u32(tail, i) !== 0x06054b50) continue;
    const count = u16(tail, i + 10), size = u32(tail, i + 12), offset = u32(tail, i + 16);
    if (count === 0xffff || offset === 0xffffffff || offset + size > total) throw new Error("not_zip");
    return { count, size, offset };
  }
  throw new Error("not_zip");
}

/// The entries of a central directory (its bytes, `count` entries).
export function readDirectory(bytes, count) {
  const entries = [];
  let p = 0;
  for (let n = 0; n < count; n++) {
    if (p + 46 > bytes.length || u32(bytes, p) !== 0x02014b50) throw new Error("not_zip");
    const nameLength = u16(bytes, p + 28);
    entries.push({
      name: new TextDecoder().decode(bytes.subarray(p + 46, p + 46 + nameLength)),
      method: u16(bytes, p + 10),
      compressed: u32(bytes, p + 20),
      size: u32(bytes, p + 24),
      link: ((u32(bytes, p + 38) >>> 16) & 0xf000) === 0xa000,
      local: u32(bytes, p + 42),
    });
    p += 46 + nameLength + u16(bytes, p + 30) + u16(bytes, p + 32);
  }
  return entries;
}

/// The package in a list of entries: its files (Finder's __MACOSX, .DS_Store and ._ extras left
/// out) and `root`, the folder holding manifest.json ("" or one top-level folder), or null.
export function inspectEntries(entries) {
  const files = entries.filter(e => {
    const base = e.name.split("/").pop();
    return !e.name.endsWith("/") && !e.name.startsWith("__MACOSX/") && base !== ".DS_Store" && !base.startsWith("._");
  });
  const unsafe = files.some(e => e.link || e.name.includes("\\") || e.name.startsWith("/") || e.name.split("/").includes(".."));
  const manifests = files.map(e => e.name.split("/")).filter(parts => parts.at(-1) === "manifest.json");
  let root = null;
  for (const depth of [1, 2]) {
    const found = manifests.filter(parts => parts.length === depth);
    if (found.length === 1) root = depth === 1 ? "" : `${found[0][0]}/`;
    if (found.length) break;
  }
  return { files, root, unsafe, unpacked: files.reduce((sum, e) => sum + e.size, 0) };
}

/// The rules for the zip itself. Returns problem codes; empty means it passes.
export function zipProblems(info, bytes) {
  const list = [];
  if (info.unsafe) list.push("unsafe");
  if (info.files.length > MAX_FILES || info.unpacked > MAX_UNPACKED) list.push("too_many");
  if (info.root === null) list.push("no_manifest");
  if (bytes > 20 * 1024 * 1024) list.push("too_large");
  return list;
}

/// Reads a whole zip held in memory: its package entries, plus `read(entry)` for their bytes.
export function inspectZipFile(bytes) {
  const where = findDirectory(bytes.subarray(Math.max(0, bytes.length - 65557)), bytes.length);
  const info = inspectEntries(readDirectory(bytes.subarray(where.offset, where.offset + where.size), where.count));
  info.read = entry => readEntry(bytes, entry);
  return info;
}

/// One entry's bytes, inflated if it was compressed (DecompressionStream, browsers and Workers).
async function readEntry(bytes, entry) {
  const p = entry.local;
  if (u32(bytes, p) !== 0x04034b50) throw new Error("not_zip");
  const start = p + 30 + u16(bytes, p + 26) + u16(bytes, p + 28);
  const data = bytes.subarray(start, start + entry.compressed);
  if (entry.method === 0) return data;
  if (entry.method !== 8) throw new Error("not_zip");
  const stream = new Blob([data]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

/// Checks the package inside (on the gallery page; the Worker leaves this to the review's
/// AVFoundation check): the manifest, an idle clip, every pose reachable from "front" and every
/// clip a transparent .mov of the canvas size, at most 10 s and 1080 px tall. Returns what it
/// found, with `problems` as codes.
export async function inspectPackage(info) {
  const found = { clips: 0, actions: 0, walks: false, width: 0, height: 0, duration: 0, problems: [] };
  const byName = new Map(info.files.map(e => [e.name, e]));
  let manifest;
  try {
    manifest = JSON.parse(new TextDecoder().decode(await info.read(byName.get(`${info.root}manifest.json`))));
  } catch {
    found.problems.push("manifest");
    return found;
  }
  const kinds = ["idle", "walk", "transition", "action", "drag"];
  const clips = (Array.isArray(manifest.clips) ? manifest.clips : [])
    .filter(c => c && typeof c.id === "string" && typeof c.file === "string" && kinds.includes(c.kind));
  Object.assign(found, {
    clips: clips.length, width: manifest.width, height: manifest.height,
    actions: clips.filter(c => c.kind === "action").length, walks: clips.some(c => c.kind === "walk"),
  });
  if (manifest.spec !== undefined && manifest.spec !== 1 || !(manifest.width > 0) || !(manifest.height > 0)) found.problems.push("manifest");
  if (!clips.some(c => c.kind === "idle")) found.problems.push("no_idle");
  const pose = (c, key) => c[key] || "front";
  const reached = new Set(["front"]);
  for (let grew = true; grew;) {
    grew = false;
    for (const c of clips) if (c.kind === "transition" && reached.has(pose(c, "from")) && !reached.has(pose(c, "to"))) {
      reached.add(pose(c, "to"));
      grew = true;
    }
  }
  if (clips.some(c => !reached.has(pose(c, "from")) || !reached.has(pose(c, "to")))) found.problems.push("unreachable");
  for (const c of clips) {
    const entry = byName.get(info.root + c.file);
    let clip;
    try {
      if (!entry || c.file.split("/").includes("..") || !/\.mov$/i.test(c.file)) throw new Error("missing");
      clip = inspectFile(await info.read(entry));
    } catch {
      found.problems.push("manifest");
      continue;
    }
    if (c.kind === "idle" && !found.duration) found.duration = clip.duration;
    if (clip.depth !== 32) found.problems.push("no_alpha");
    if (!(clip.duration > 0) || clip.duration > 10) found.problems.push("length");
    if (clip.width !== manifest.width || clip.height !== manifest.height) found.problems.push("canvas");
  }
  if (found.height > 1080) found.problems.push("height");
  found.problems = [...new Set(found.problems)];
  return found;
}
