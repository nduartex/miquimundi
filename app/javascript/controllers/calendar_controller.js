import { Controller } from "@hotwired/stimulus"

// Jumps the match calendar straight to today's card on load (or the next
// upcoming day, decided server-side). No-op when there's no target — e.g. a
// page with no days. Respects reduced-motion.
export default class extends Controller {
  static targets = ["today"]

  connect() {
    if (!this.hasTodayTarget) return
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    // Defer one frame so layout/fonts settle before measuring scroll position.
    requestAnimationFrame(() => {
      this.todayTarget.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" })
    })
  }
}
