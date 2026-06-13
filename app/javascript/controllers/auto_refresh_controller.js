import { Controller } from "@hotwired/stimulus"

// Periodically refreshes the current page while something is live (e.g. the
// standings projection during a match). Pairs with the page's
// turbo-refresh-method=morph meta tags so positions update in place without
// losing scroll. Pauses while the tab is hidden to avoid pointless requests.
export default class extends Controller {
  static values = { interval: { type: Number, default: 60000 } }

  connect() {
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  refresh() {
    if (document.visibilityState !== "visible") return
    Turbo.visit(window.location.href, { action: "replace" })
  }
}
