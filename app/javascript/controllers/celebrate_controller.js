import { Controller } from "@hotwired/stimulus"

// Celebration modal shown once, right after the first part of the quiniela is
// completed and saved. Fires confetti on connect and stays until the user acts
// (no auto-dismiss), so the milestone is clearly seen.
export default class extends Controller {
  connect() {
    this.burst()
    // Clean the ?fase1=1 flag from the URL so a refresh doesn't re-open it.
    if (window.history.replaceState) {
      const url = new URL(window.location.href)
      url.searchParams.delete("fase1")
      window.history.replaceState({}, "", url)
    }
  }

  close() {
    this.element.remove()
  }

  // Confetti rain (same look as the confetti controller, kept self-contained).
  burst() {
    const colors = ["#ffc531", "#4ade80", "#38bdf8", "#ff5d7d"]
    for (let i = 0; i < 80; i++) {
      const c = document.createElement("div")
      c.style.cssText = `position:fixed;top:-10px;left:${Math.random() * 100}vw;width:10px;height:10px;background:${colors[i % 4]};z-index:10000;border-radius:2px;transition:transform 2.4s ease-out, opacity 2.4s;`
      document.body.appendChild(c)
      requestAnimationFrame(() => {
        c.style.transform = `translateY(100vh) rotate(${Math.random() * 720}deg)`
        c.style.opacity = "0"
      })
      setTimeout(() => c.remove(), 2600)
    }
  }
}
