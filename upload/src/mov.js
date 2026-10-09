// Reads what the gallery needs from a QuickTime (.mov) file's metadata box ("moov"):
// the video codec, frame size, bit depth (32 means it carries an alpha channel) and length.
// Shared by the upload Worker and the gallery page: edit upload/src/mov.js and copy it to gallery/mov.js.

export function readBoxHeader(bytes, offset, end) {
  if (offset + 8 > end) return null;
  const view = new DataView(bytes.buffer, bytes.byteOffset);
  let size = view.getUint32(offset);
  const type = String.fromCharCode(...bytes.subarray(offset + 4, offset + 8));
  let header = 8;
  if (size === 1) {
    if (offset + 16 > end) return null;
    size = Number(view.getBigUint64(offset + 8));
    header = 16;
  } else if (size === 0) {
    size = end - offset;
  }
  if (size < header) return null;
  return { type, offset, start: offset + header, end: offset + size, size };
}

function* boxes(bytes, start, end) {
  let offset = start;
  while (offset < end) {
    const box = readBoxHeader(bytes, offset, end);
    if (!box || box.end > end) return;
    yield box;
    offset = box.end;
  }
}

function child(bytes, parent, path) {
  let box = parent;
  for (const type of path) {
    box = [...boxes(bytes, box.start, box.end)].find((b) => b.type === type);
    if (!box) return null;
  }
  return box;
}

/// Parses a "moov" box (the bytes of the whole box, header included).
export function inspectMoov(bytes) {
  const moov = readBoxHeader(bytes, 0, bytes.length);
  if (!moov || moov.type !== "moov") throw new Error("not_mov");
  const view = new DataView(bytes.buffer, bytes.byteOffset);
  const mvhd = child(bytes, moov, ["mvhd"]);
  if (!mvhd) throw new Error("not_mov");
  const v1 = bytes[mvhd.start] === 1;
  const timescale = view.getUint32(mvhd.start + (v1 ? 20 : 12));
  const length = v1 ? Number(view.getBigUint64(mvhd.start + 24)) : view.getUint32(mvhd.start + 16);
  const duration = timescale ? Math.round((length / timescale) * 10) / 10 : 0;

  for (const trak of boxes(bytes, moov.start, moov.end)) {
    if (trak.type !== "trak") continue;
    const hdlr = child(bytes, trak, ["mdia", "hdlr"]);
    if (!hdlr || String.fromCharCode(...bytes.subarray(hdlr.start + 8, hdlr.start + 12)) !== "vide") continue;
    const stsd = child(bytes, trak, ["mdia", "minf", "stbl", "stsd"]);
    if (!stsd) continue;
    const entry = stsd.start + 8;
    if (entry + 84 > stsd.end) continue;
    return {
      codec: String.fromCharCode(...bytes.subarray(entry + 4, entry + 8)),
      width: view.getUint16(entry + 32),
      height: view.getUint16(entry + 34),
      depth: view.getUint16(entry + 82),
      duration,
    };
  }
  throw new Error("no_video");
}

/// The rules every gallery character must meet. Returns problem codes; empty means it passes.
export function problems(info, bytes) {
  const list = [];
  if (info.depth !== 32) list.push("no_alpha");
  if (info.duration < 2 || info.duration > 10) list.push("length");
  if (info.height > 1080) list.push("height");
  if (bytes > 30 * 1024 * 1024) list.push("too_large");
  return list;
}

/// Finds and parses the "moov" box in a whole file held in memory.
export function inspectFile(bytes) {
  for (const box of boxes(bytes, 0, bytes.length)) {
    if (box.type === "moov") return inspectMoov(bytes.subarray(box.offset, box.end));
  }
  throw new Error("not_mov");
}
