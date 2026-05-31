import { Controller } from "@hotwired/stimulus"

// Watches the live-updating ranking; when the #1 row's user changes (after a
// Turbo broadcast replaces the table), flies a 👑 onto the new leader's row.
export default class extends Controller {
  connect() {
    this.ranking = this.element.querySelector("#ranking")
    if (!this.ranking) return
    this.leaderId = this.topUserId()
    this.observer = new MutationObserver(() => this.check())
    this.observer.observe(this.ranking, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer && this.observer.disconnect()
  }

  topUserId() {
    return this.ranking.querySelector("[data-user-id]")?.dataset.userId || null
  }

  check() {
    const now = this.topUserId()
    if (!now || now === this.leaderId) { this.leaderId = now; return }
    this.leaderId = now
    const row = this.ranking.querySelector(`[data-user-id="${now}"]`)
    if (!row) return
    const crown = document.createElement("div")
    crown.textContent = "👑"
    crown.className = "crown-fly"
    const r = row.getBoundingClientRect()
    crown.style.left = `${r.left + 12}px`
    crown.style.top = `${r.top - 8}px`
    document.body.appendChild(crown)
    setTimeout(() => crown.remove(), 1600)
  }
}
