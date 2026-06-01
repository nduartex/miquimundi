import { Controller } from "@hotwired/stimulus"

// Lightweight modal: shows/hides a panel target. Closes on the ✕/button, on a
// backdrop click, or with Escape.
export default class extends Controller {
  static targets = ["panel"]

  open() {
    this.panelTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    this._esc = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this._esc)
  }

  close() {
    this.panelTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    if (this._esc) document.removeEventListener("keydown", this._esc)
  }

  // Close only when the click lands on the backdrop itself, not its content.
  backdrop(event) {
    if (event.target === this.panelTarget) this.close()
  }
}
