// The share button on each gallery card and its popover: the character's link (c/<id>/, built by
// scripts/gallery_pages.py with its own Open Graph card), copy, post on X and the system share sheet.
// On touch devices with a share sheet the button opens the sheet directly.

const strings = {
  en: { share: "Share {name}", preview: "Shows up like this on X, WeChat and iMessage", link: "Share link", copy: "Copy", copied: "Copied", x: "Post on X", more: "More…", close: "Close" },
  zh: { share: "分享 {name}", preview: "发到 X、微信、iMessage 时显示这张卡", link: "分享链接", copy: "复制", copied: "已复制", x: "发到 X", more: "更多…", close: "关闭" },
};

const shareIcon = '<svg class="icon" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M8 10V2M5 4.8 8 1.8l3 3M5.5 7H4a1 1 0 0 0-1 1v5a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1V8a1 1 0 0 0-1-1h-1.5"/></svg>';
const xIcon = '<svg class="icon" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M12.2 1.5h2.2L9.6 7l5.6 7.5h-4.4L7.4 10l-4 4.5H1.2l5.1-5.8L1 1.5h4.5l3.1 4.1 3.6-4.1Zm-.8 11.7h1.2L4.8 2.7H3.5l7.9 10.5Z"/></svg>';
const closeIcon = '<svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true"><path d="M2.5 2.5l7 7M9.5 2.5l-7 7"/></svg>';

let open = null;

export const shareURL = c => new URL(`c/${c.id}/`, location.href).href;

export function shareButton(c, lang) {
  const t = strings[lang] || strings.en;
  const label = t.share.replace("{name}", c.name);
  const button = node("button", { className: "share-btn", type: "button", title: label });
  button.setAttribute("aria-label", label);
  button.setAttribute("aria-haspopup", "dialog");
  button.setAttribute("aria-expanded", "false");
  button.innerHTML = shareIcon;
  button.addEventListener("click", () => {
    const touch = matchMedia("(hover: none)").matches;
    if (touch && navigator.share) {
      navigator.share({ title: `${c.name} · Cameo`, url: shareURL(c) }).catch(() => {});
    } else if (open?.button === button) {
      close();
    } else {
      show(c, t, button);
    }
  });
  return button;
}

function show(c, t, button) {
  close();
  const url = shareURL(c);
  const pop = node("div", { className: "share-pop", role: "dialog" });
  pop.setAttribute("aria-label", t.share.replace("{name}", c.name));

  const shut = node("button", { className: "share-close", type: "button" });
  shut.setAttribute("aria-label", t.close);
  shut.innerHTML = closeIcon;
  shut.addEventListener("click", () => close(true));

  const field = node("input", { readOnly: true, value: url.replace(/^https?:\/\//, "") });
  field.setAttribute("aria-label", t.link);
  field.addEventListener("focus", () => field.select());
  const copy = node("button", { className: "share-copy", type: "button", textContent: t.copy });
  copy.addEventListener("click", async () => {
    try { await navigator.clipboard.writeText(url); } catch { field.select(); return; }
    copy.textContent = t.copied;
    copy.classList.add("done");
    clearTimeout(copy.reset);
    copy.reset = setTimeout(() => { copy.textContent = t.copy; copy.classList.remove("done"); }, 1500);
  });

  const x = node("a", { className: "btn btn-dark btn-sm", target: "_blank", rel: "noopener",
    href: `https://x.com/intent/post?text=${encodeURIComponent(`${c.name} · Cameo`)}&url=${encodeURIComponent(url)}` });
  x.innerHTML = xIcon;
  x.append(t.x);
  const actions = node("div", { className: "share-actions" }, x);
  if (navigator.share) {
    const more = node("button", { className: "btn btn-soft btn-sm", type: "button", textContent: t.more });
    more.addEventListener("click", () => navigator.share({ title: `${c.name} · Cameo`, url }).catch(() => {}));
    actions.append(more);
  }

  const preview = node("img", { className: "share-card", src: `og/${c.id}.png`, alt: "", width: 1200, height: 630 });
  preview.addEventListener("error", () => preview.remove(), { once: true });

  pop.append(
    node("div", { className: "share-head" }, node("strong", { textContent: t.share.replace("{name}", c.name) }), shut),
    preview,
    node("span", { className: "share-note", textContent: t.preview }),
    node("div", { className: "share-link" }, field, copy),
    actions);
  document.body.append(pop);
  place(pop, button);
  button.setAttribute("aria-expanded", "true");
  open = { pop, button };
  copy.focus();
}

// Below the button, right-aligned to it, kept inside the page.
function place(pop, button) {
  const r = button.getBoundingClientRect();
  const width = pop.offsetWidth;
  const left = Math.min(Math.max(16, r.right - width), document.documentElement.clientWidth - width - 16);
  pop.style.left = `${left + scrollX}px`;
  pop.style.top = `${r.bottom + scrollY + 8}px`;
}

function close(refocus) {
  if (!open) return;
  open.pop.remove();
  open.button.setAttribute("aria-expanded", "false");
  if (refocus) open.button.focus();
  open = null;
}

document.addEventListener("pointerdown", event => {
  if (open && !open.pop.contains(event.target) && !open.button.contains(event.target)) close();
});
document.addEventListener("keydown", event => { if (event.key === "Escape" && open) close(true); });
addEventListener("resize", () => close());

function node(tag, props, ...children) {
  const n = Object.assign(document.createElement(tag), props);
  n.append(...children);
  return n;
}
