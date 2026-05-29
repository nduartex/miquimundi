import { Controller } from "@hotwired/stimulus"

// Ticking countdown to a target datetime. Updates only text nodes (markup +
// classes live in the view) and stops when the date passes.
export default class extends Controller {
  static values = { target: String }
  static targets = ["days", "hours", "mins", "secs", "grid", "done"]

  connect() {
    this.update()
    this.timer = setInterval(() => this.update(), 1000)
  }

  disconnect() { clearInterval(this.timer) }

  update() {
    const diff = new Date(this.targetValue) - new Date()
    if (diff <= 0) {
      if (this.hasGridTarget) this.gridTarget.classList.add("hidden")
      if (this.hasDoneTarget) this.doneTarget.classList.remove("hidden")
      clearInterval(this.timer)
      return
    }
    const total = Math.floor(diff / 1000)
    const d = Math.floor(total / 86400)
    const h = Math.floor((total % 86400) / 3600)
    const m = Math.floor((total % 3600) / 60)
    const s = total % 60
    if (this.hasDaysTarget) this.daysTarget.textContent = d
    if (this.hasHoursTarget) this.hoursTarget.textContent = String(h).padStart(2, "0")
    if (this.hasMinsTarget) this.minsTarget.textContent = String(m).padStart(2, "0")
    if (this.hasSecsTarget) this.secsTarget.textContent = String(s).padStart(2, "0")
  }
}
