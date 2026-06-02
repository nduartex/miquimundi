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

  // Pointer drag (mouse + touch). Desktop (mouse/pen): grab the row from
  // anywhere. Touch: only from the ⠿ grip, so a finger can still scroll the
  // list without hijacking it into a drag.
  start(event) {
    if (event.button != null && event.button !== 0) return // left button / touch only
    if (event.pointerType === "touch" && !event.target.closest("[data-grip]")) return
    const item = event.currentTarget.closest("[data-group-order-target='item']")
    if (!item) return
    event.preventDefault()

    this.dragging = item
    // Desktop (mouse/pen): the card lifts and tracks the cursor freely, and is
    // dropped wherever you release it. Touch: live reorder between slots.
    this.follow = event.pointerType !== "touch"
    this.grabOffset = event.clientY - item.getBoundingClientRect().top
    event.currentTarget.setPointerCapture?.(event.pointerId)
    item.style.transition = "none" // instant tracking; no easing lag while dragging
    item.classList.add(...DRAG_CLASSES)

    this._move = this.onMove.bind(this)
    this._end = this.onEnd.bind(this)
    document.addEventListener("pointermove", this._move)
    document.addEventListener("pointerup", this._end)
    document.addEventListener("pointercancel", this._end)
  }

  onMove(event) {
    if (!this.dragging) return
    if (this.follow) {
      // Free movement: glue the grabbed point of the card to the cursor.
      this.dragging.style.transform = "none"
      const top = this.dragging.getBoundingClientRect().top
      this.dragging.style.transform = `translateY(${event.clientY - top - this.grabOffset}px) scale(1.02)`
      return
    }
    this.placeAt(event.clientY)
    this.sync()
  }

  onEnd(event) {
    if (!this.dragging) return
    // Desktop: settle into the slot under the release point.
    if (this.follow && event) this.placeAt(event.clientY)
    this.dragging.style.transform = "" // snap into the final slot (transition still off)
    this.dragging.style.transition = ""
    this.dragging.classList.remove(...DRAG_CLASSES)
    this.dragging = null
    document.removeEventListener("pointermove", this._move)
    document.removeEventListener("pointerup", this._end)
    document.removeEventListener("pointercancel", this._end)
    this.sync()
  }

  // Moves the dragged row into the slot whose midpoint sits below `y`.
  placeAt(y) {
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
