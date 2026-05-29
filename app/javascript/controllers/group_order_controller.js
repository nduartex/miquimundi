import { Controller } from "@hotwired/stimulus"

// Ranks the 4 teams of a group by drag-and-drop (desktop) or ↑/↓ buttons
// (mobile/accessible). Keeps 4 hidden inputs (1st..4th) in sync and notifies
// the bracket engine so flags propagate into the knockout stage.
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

  up(event) {
    const i = this.itemTargets.indexOf(event.currentTarget.closest("[data-group-order-target='item']"))
    this.reorder(i, i - 1)
  }

  down(event) {
    const i = this.itemTargets.indexOf(event.currentTarget.closest("[data-group-order-target='item']"))
    this.reorder(i, i + 1)
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
    })
    window.dispatchEvent(new CustomEvent("bracket:changed"))
  }
}
