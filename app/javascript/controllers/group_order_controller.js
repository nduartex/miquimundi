import { Controller } from "@hotwired/stimulus"

// Ranks the 4 teams of a group via pointer drag from the ⠿ grip — unified
// mouse + touch (Pointer Events, so it works on phones where native HTML5 drag
// never fires). Keeps 4 hidden inputs (1st..4th) in sync and notifies the
// bracket engine so flags propagate into the knockout stage.
// Per-rank accent colours, kept in sync with _group_stage's row_accents:
// 1º-2º grass (qualify), 3º gold (best-third candidate), 4º muted.
const ROW_ACCENTS = ["var(--color-grass)", "var(--color-grass)", "var(--color-gold)", "#9fb3a6"]
const DRAG_CLASSES = ["opacity-80", "ring-2", "ring-white/30", "scale-[1.02]", "z-10"]

export default class extends Controller {
  static targets = ["list", "item", "hidden"]

  connect() { this.sync() }

  // Pointer drag (mouse + touch) initiated from a row's grip handle.
  start(event) {
    if (event.button != null && event.button !== 0) return // left button / touch only
    const item = event.currentTarget.closest("[data-group-order-target='item']")
    if (!item) return
    event.preventDefault()

    this.dragging = item
    event.currentTarget.setPointerCapture?.(event.pointerId)
    item.classList.add(...DRAG_CLASSES)

    this._move = this.onMove.bind(this)
    this._end = this.onEnd.bind(this)
    document.addEventListener("pointermove", this._move)
    document.addEventListener("pointerup", this._end)
    document.addEventListener("pointercancel", this._end)
  }

  onMove(event) {
    if (!this.dragging) return
    const y = event.clientY
    const others = this.itemTargets.filter((el) => el !== this.dragging)
    const before = others.find((el) => {
      const r = el.getBoundingClientRect()
      return y < r.top + r.height / 2
    })
    if (before) {
      if (before.previousElementSibling !== this.dragging) this.listTarget.insertBefore(this.dragging, before)
    } else if (this.listTarget.lastElementChild !== this.dragging) {
      this.listTarget.appendChild(this.dragging)
    }
    this.sync()
  }

  onEnd() {
    if (!this.dragging) return
    this.dragging.classList.remove(...DRAG_CLASSES)
    this.dragging = null
    document.removeEventListener("pointermove", this._move)
    document.removeEventListener("pointerup", this._end)
    document.removeEventListener("pointercancel", this._end)
    this.sync()
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
