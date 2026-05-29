import { Controller } from "@hotwired/stimulus"

// Accessible custom dropdown that shows a real flag image + country name in
// each option (native <select> can't render images, and emoji flags don't
// render on Windows). Backed by a hidden input that submits the team id.
export default class extends Controller {
  static targets = ["hidden", "button", "display", "list", "option"]
  static values = { placeholder: String }

  connect() {
    this.active = -1
    this.onDocClick = (e) => { if (!this.element.contains(e.target)) this.close() }
    document.addEventListener("click", this.onDocClick)
    this.syncDisplay()
  }

  disconnect() { document.removeEventListener("click", this.onDocClick) }

  get expanded() { return this.buttonTarget.getAttribute("aria-expanded") === "true" }

  toggle() { this.expanded ? this.close() : this.open() }

  open() {
    this.listTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    const sel = this.optionTargets.findIndex((o) => o.getAttribute("aria-selected") === "true")
    this.active = sel >= 0 ? sel : 0
    this.highlight()
    this.optionTargets[this.active]?.scrollIntoView({ block: "nearest" })
  }

  close() {
    this.listTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  select(event) {
    this.choose(event.currentTarget)
    this.close()
    this.buttonTarget.focus()
  }

  choose(li) {
    this.hiddenTarget.value = li.dataset.value
    this.optionTargets.forEach((o) => o.setAttribute("aria-selected", o === li ? "true" : "false"))
    this.displayTarget.innerHTML = li.innerHTML
    this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  syncDisplay() {
    const sel = this.optionTargets.find((o) => o.getAttribute("aria-selected") === "true")
    if (sel) this.displayTarget.innerHTML = sel.innerHTML
  }

  onKey(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.expanded ? this.move(1) : this.open()
        break
      case "ArrowUp":
        event.preventDefault()
        this.expanded ? this.move(-1) : this.open()
        break
      case "Enter":
      case " ":
        event.preventDefault()
        if (this.expanded) { this.choose(this.optionTargets[this.active]); this.close() }
        else this.open()
        break
      case "Escape":
        this.close()
        break
    }
  }

  move(delta) {
    this.active = Math.max(0, Math.min(this.optionTargets.length - 1, this.active + delta))
    this.highlight()
    this.optionTargets[this.active]?.scrollIntoView({ block: "nearest" })
  }

  highlight() {
    this.optionTargets.forEach((o, i) => o.classList.toggle("bg-white/10", i === this.active))
  }
}
