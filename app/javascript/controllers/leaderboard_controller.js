import { Controller } from "@hotwired/stimulus"

// Watches the live-updating ranking; when the #1 row's user changes (after a
// Turbo broadcast replaces the table), flies a 👑 onto the new leader's row.
// Also marks the signed-in user's own row ("Tú") so they can find themselves.
export default class extends Controller {
  static values = { me: String }

  connect() {
    this.ranking = this.element.querySelector("#ranking")
    if (!this.ranking) return
    this.leaderId = this.topUserId()
    this.highlightMe()
    // Each broadcast replaces #ranking with fresh DOM, so re-apply our marker.
    this.observer = new MutationObserver(() => { this.check(); this.highlightMe() })
    this.observer.observe(this.ranking, { childList: true, subtree: true })
  }

  // Add a sky ring + "Tú" pill to the current user's row. Idempotent per render.
  highlightMe() {
    const id = this.meValue
    if (!id) return
    const row = this.ranking.querySelector(`[data-user-id="${id}"]`)
    if (!row || row.dataset.you === "1") return
    row.dataset.you = "1"
    // The leader row already carries its own amber ring; just badge it.
    if (!row.classList.contains("ring-amber-300")) row.classList.add("ranking-you")
    const line = row.querySelector("[data-name]")
    if (line && !line.querySelector(".you-badge")) {
      const badge = document.createElement("span")
      badge.className = "you-badge"
      badge.textContent = "Tú"
      line.appendChild(badge)
    }
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
