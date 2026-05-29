import { Controller } from "@hotwired/stimulus"

// Number stepper: − / + buttons around a numeric input, clamped at 0.
export default class extends Controller {
  static targets = ["input"]

  inc() { this.set(this.value + 1) }
  dec() { this.set(this.value - 1) }

  get value() {
    const n = parseInt(this.inputTarget.value, 10)
    return Number.isNaN(n) ? 0 : n
  }

  set(n) {
    if (this.inputTarget.disabled) return
    this.inputTarget.value = Math.max(0, n)
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
