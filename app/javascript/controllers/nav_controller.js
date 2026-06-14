import { Controller } from "@hotwired/stimulus"

// Mobile nav: toggles the stacked links panel behind the hamburger button.
// Closes on Escape, on an outside click, when a link is tapped, and whenever
// the viewport grows to the breakpoint where the full bar is shown again.
export default class extends Controller {
  static targets = ["menu", "open", "close"]

  toggle() {
    this.menuTarget.classList.contains("hidden") ? this.show() : this.hide()
  }

  show() {
    this.menuTarget.classList.remove("hidden")
    this._toggleIcons(true)
    this.element.setAttribute("aria-expanded", "true")
    this._outside = (e) => { if (!this.element.contains(e.target)) this.hide() }
    this._esc = (e) => { if (e.key === "Escape") this.hide() }
    // Defer so the click that opened the menu doesn't immediately close it.
    setTimeout(() => document.addEventListener("click", this._outside))
    document.addEventListener("keydown", this._esc)
  }

  hide() {
    this.menuTarget.classList.add("hidden")
    this._toggleIcons(false)
    this.element.setAttribute("aria-expanded", "false")
    if (this._outside) document.removeEventListener("click", this._outside)
    if (this._esc) document.removeEventListener("keydown", this._esc)
  }

  disconnect() {
    if (this._outside) document.removeEventListener("click", this._outside)
    if (this._esc) document.removeEventListener("keydown", this._esc)
  }

  _toggleIcons(open) {
    if (this.hasOpenTarget) this.openTarget.classList.toggle("hidden", open)
    if (this.hasCloseTarget) this.closeTarget.classList.toggle("hidden", !open)
  }
}
