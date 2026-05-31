import { Controller } from "@hotwired/stimulus"

// Celebration: fires confetti on connect (intensity by `level`) and stays until
// the user closes it. Cleans its trigger params from the URL so a refresh won't
// re-open it.
export default class extends Controller {
  static values = { level: { type: String, default: "normal" } }

  connect() {
    this.burst()
    if (window.history.replaceState) {
      const url = new URL(window.location.href)
      ;["fase1", "logros"].forEach((p) => url.searchParams.delete(p))
      window.history.replaceState({}, "", url)
    }
  }

  close() {
    this.element.remove()
  }

  burst() {
    const epic = this.levelValue === "epic"
    const colors = epic
      ? ["#ffc531", "#ffd766", "#f0a800", "#4ade80", "#38bdf8"]
      : ["#ffc531", "#4ade80", "#38bdf8", "#ff5d7d"]
    const count = epic ? 160 : 80
    const fall = epic ? 3.2 : 2.4
    for (let i = 0; i < count; i++) {
      const c = document.createElement("div")
      c.style.cssText = `position:fixed;top:-10px;left:${Math.random() * 100}vw;width:10px;height:10px;background:${colors[i % colors.length]};z-index:10000;border-radius:2px;transition:transform ${fall}s ease-out, opacity ${fall}s;`
      document.body.appendChild(c)
      requestAnimationFrame(() => {
        c.style.transform = `translateY(100vh) rotate(${Math.random() * 720}deg)`
        c.style.opacity = "0"
      })
      setTimeout(() => c.remove(), fall * 1000 + 200)
    }
  }
}
