import { Controller } from "@hotwired/stimulus"

// Copies the source field's value to the clipboard and flashes feedback.
export default class extends Controller {
  static targets = ["source", "btn"]

  copy() {
    const text = this.sourceTarget.value ?? this.sourceTarget.textContent
    const done = () => {
      const b = this.btnTarget
      const original = b.textContent
      b.textContent = "¡Copiado!"
      setTimeout(() => (b.textContent = original), 1500)
    }
    if (navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(text).then(done).catch(() => this.fallback(done))
    } else {
      this.fallback(done)
    }
  }

  fallback(done) {
    this.sourceTarget.select()
    try { document.execCommand("copy"); done() } catch { /* ignore */ }
  }
}
