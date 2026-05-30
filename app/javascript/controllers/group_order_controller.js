import { Controller } from "@hotwired/stimulus"

// Ranks the 4 teams of a group by drag-and-drop (desktop) or ↑/↓ buttons
// (mobile/accessible). Keeps 4 hidden inputs (1st..4th) in sync and notifies
// the bracket engine so flags propagate into the knockout stage.
// Per-rank accent colours, kept in sync with _group_stage's row_accents:
// 1º-2º grass (qualify), 3º gold (best-third candidate), 4º muted.
const ROW_ACCENTS = ["var(--color-grass)", "var(--color-grass)", "var(--color-gold)", "#9fb3a6"]

export default class extends Controller {
  static targets = ["list", "item", "hidden"]

  connect() { this.sync() }

  dragStart(event) {
    this.dragIndex = this.itemTargets.indexOf(event.currentTarget)
    event.dataTransfer.effectAllowed = "move"
    event.currentTarget.classList.add("opacity-50")
  }

  dragEnd(event) { event.currentTarget.classList.remove("opacity-50") }

  dragOver(event) { event.preventDefault() }

  drop(event) {
    event.preventDefault()
    const to = this.itemTargets.indexOf(event.currentTarget)
    this.reorder(this.dragIndex, to)
  }

  reorder(from, to) {
    if (from == null || to < 0 || to >= this.itemTargets.length || from === to) return
    const items = [...this.itemTargets]
    const [moved] = items.splice(from, 1)
    items.splice(to, 0, moved)
    items.forEach((el) => this.listTarget.appendChild(el))
    this.sync()
  }

  sync() {
    this.itemTargets.forEach((item, i) => {
      const pos = item.querySelector("[data-pos]")
      if (pos) pos.textContent = i + 1
      if (this.hiddenTargets[i]) this.hiddenTargets[i].value = item.dataset.teamId
      item.style.setProperty("--accent", ROW_ACCENTS[i] ?? ROW_ACCENTS[ROW_ACCENTS.length - 1])
      item.classList.toggle("is-out", i === 3)
    })
    window.dispatchEvent(new CustomEvent("bracket:changed"))
  }
}
