import { Controller } from "@hotwired/stimulus"

// Searchable player picker. Reads the shared players dataset (#players-json),
// filters as you type, and shows "name + country (flag)" suggestions. Writes
// the chosen player id into a hidden field.
export default class extends Controller {
  static targets = ["input", "hidden", "list"]

  connect() {
    this.data = window.__playersData ||= JSON.parse(document.getElementById("players-json")?.textContent || "[]")
    this.active = -1
  }

  filter() {
    const q = this.inputTarget.value.trim().toLowerCase()
    if (this.hiddenTarget.value && q !== this.lastChosenLabel) this.hiddenTarget.value = ""
    if (q.length < 1) { this.close(); return }
    const matches = this.data.filter(
      (p) => p.name.toLowerCase().includes(q) || p.country.toLowerCase().includes(q)
    ).slice(0, 8)
    this.render(matches)
  }

  render(matches) {
    if (!matches.length) { this.close(); return }
    this.listTarget.innerHTML = matches.map((p, i) => `
      <li role="option" data-id="${p.id}" data-label="${esc(p.name)}"
          data-action="mousedown->combobox#choose"
          class="flex items-center gap-2 px-3 py-2 cursor-pointer hover:bg-white/10 ${i === 0 ? "bg-white/5" : ""}">
        ${p.flag ? `<img src="${p.flag}" alt="" class="w-[22px] h-[16px] rounded-sm object-cover ring-1 ring-white/15 shrink-0">` : ""}
        <span class="text-white truncate">${esc(p.name)}</span>
        <span class="text-white/40 text-xs ml-auto shrink-0">${esc(p.country)}</span>
      </li>`).join("")
    this.listTarget.hidden = false
    this.active = -1
  }

  choose(event) {
    const li = event.currentTarget
    this.hiddenTarget.value = li.dataset.id
    this.inputTarget.value = li.dataset.label
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

  blur() { setTimeout(() => this.close(), 150) }
  close() { this.listTarget.hidden = true }
}

function esc(s) {
  const d = document.createElement("div")
  d.textContent = s == null ? "" : String(s)
  return d.innerHTML
}
