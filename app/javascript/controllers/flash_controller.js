import { Controller } from "@hotwired/stimulus"

// Auto-dismissing toast: fades out after `delay` ms, or on close click.
export default class extends Controller {
  static values = { delay: { type: Number, default: 4000 } }

  connect() { this.timer = setTimeout(() => this.dismiss(), this.delayValue) }
  disconnect() { clearTimeout(this.timer) }

  dismiss() {
    clearTimeout(this.timer)
    this.element.classList.add("toast-out")
    const remove = () => this.element.remove()
    this.element.addEventListener("transitionend", remove, { once: true })
    setTimeout(remove, 450) // fallback if no transition fires
  }
}
