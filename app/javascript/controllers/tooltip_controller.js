import { Controller } from "@hotwired/stimulus"

// Tap/click info tooltip. Toggles a bubble; closes on outside click or Escape.
export default class extends Controller {
  static targets = ["bubble"]

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.bubbleTarget.hidden ? this.open() : this.hide()
  }

  open() {
    this.bubbleTarget.hidden = false
    this.onDoc = (e) => { if (!this.element.contains(e.target)) this.hide() }
    this.onKey = (e) => { if (e.key === "Escape") this.hide() }
    document.addEventListener("click", this.onDoc)
    document.addEventListener("keydown", this.onKey)
  }

  hide() {
    this.bubbleTarget.hidden = true
    if (this.onDoc) document.removeEventListener("click", this.onDoc)
    if (this.onKey) document.removeEventListener("keydown", this.onKey)
    this.onDoc = this.onKey = null
  }

  disconnect() { this.hide() }
}
