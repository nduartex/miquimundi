import { Controller } from "@hotwired/stimulus"

// Searchable player picker. Reads the shared players dataset (#players-json),
// filters as you type, and shows "name + country (flag)" suggestions. Writes
// the chosen player id into a hidden field.
export default class extends Controller {
  static targets = ["input", "hidden", "list"]
  static values = {
    datasetId: { type: String, default: "players-json" },
    position: { type: String, default: "" },
  }

  connect() {
    const cache = (window.__cbData ||= {})
    const all = cache[this.datasetIdValue] ||=
      JSON.parse(document.getElementById(this.datasetIdValue)?.textContent || "[]")
    // When a position is set (e.g. Guante de Oro → goalkeeper) only that
    // position is suggested; otherwise every player is searchable.
    this.items = this.positionValue
      ? all.filter((p) => p.position === this.positionValue)
      : all
    this.active = -1
    // Un valor renderizado por el servidor (editando una predicción) ya cuenta
    // como selección válida.
    if (this.hiddenTarget.value && this.inputTarget.value) {
      this.chosenLabel = this.inputTarget.value
      this.lastChosenLabel = this.inputTarget.value.toLowerCase()
    }
  }

  filter() {
    const q = this.inputTarget.value.trim().toLowerCase()
    if (this.hiddenTarget.value && q !== this.lastChosenLabel) this.hiddenTarget.value = ""
    if (q.length < 1) { this.close(); return }
    const matches = this.items.filter(
      (p) => p.name.toLowerCase().includes(q) || p.country.toLowerCase().includes(q)
    ).slice(0, 8)
    this.render(matches)
  }

  render(matches) {
    if (!matches.length) { this.close(); return }
    this.listTarget.innerHTML = matches.map((p, i) => {
      const flag = safeFlag(p.flag)
      const img = flag ? `<img src="${esc(flag)}" alt="" class="w-[22px] h-[16px] rounded-sm object-cover ring-1 ring-white/15 shrink-0">` : ""
      return `
      <li role="option" data-id="${esc(String(p.id))}" data-label="${esc(p.name)}"
          data-action="mousedown->combobox#choose"
          class="flex items-center gap-2 px-3 py-2 cursor-pointer hover:bg-white/10 ${i === 0 ? "bg-white/5" : ""}">
        ${img}
        <span class="text-white truncate">${esc(p.name)}</span>
        <span class="text-white/40 text-xs ml-auto shrink-0">${esc(p.country)}</span>
      </li>`
    }).join("")
    this.listTarget.hidden = false
    this.active = -1
  }

  choose(event) {
    const li = event.currentTarget
    this.hiddenTarget.value = li.dataset.id
    this.inputTarget.value = li.dataset.label
    this.chosenLabel = li.dataset.label
    this.lastChosenLabel = li.dataset.label.toLowerCase()
    this.close()
  }

  key(event) {
    const items = Array.from(this.listTarget.querySelectorAll("li"))
    if (!items.length) return
    if (event.key === "ArrowDown") { event.preventDefault(); this.move(items, 1) }
    else if (event.key === "ArrowUp") { event.preventDefault(); this.move(items, -1) }
    else if (event.key === "Enter") { event.preventDefault(); (items[this.active] || items[0])?.dispatchEvent(new Event("mousedown")) }
    else if (event.key === "Escape") { this.close() }
  }

  move(items, d) {
    this.active = Math.max(0, Math.min(items.length - 1, this.active + d))
    items.forEach((it, i) => it.classList.toggle("bg-white/15", i === this.active))
    items[this.active]?.scrollIntoView({ block: "nearest" })
  }

  // Solo vale una selección hecha desde la lista. Si al salir del campo no hay
  // un jugador elegido (id en el hidden), borramos el texto tecleado para que
  // nadie pueda "marcar" un nombre suelto sin seleccionarlo. Si hay selección,
  // restauramos su etiqueta por si el usuario editó el texto sin re-elegir.
  blur() {
    setTimeout(() => {
      this.close()
      if (!this.hiddenTarget.value) {
        this.inputTarget.value = ""
      } else if (this.chosenLabel) {
        this.inputTarget.value = this.chosenLabel
      }
    }, 150)
  }
  close() { this.listTarget.hidden = true }
}

// Quote-aware escaper (safe for attribute context, not just text nodes).
function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#39;")
}

// Allow http(s) URLs or a same-origin root-relative path like /flags/ar.png
// (single leading slash). Blocks //host, javascript: and data: URIs.
function safeFlag(url) {
  url = url || ""
  return /^https?:\/\//i.test(url) || /^\/[^/]/.test(url) ? url : null
}
