import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  burst() {
    const colors = ["#fbbf24", "#ec4899", "#34d399", "#60a5fa"]
    for (let i = 0; i < 60; i++) {
      const c = document.createElement("div")
      c.style.cssText = `position:fixed;top:-10px;left:${Math.random()*100}vw;width:10px;height:10px;background:${colors[i%4]};z-index:9999;border-radius:2px;transition:transform 2s ease-out, opacity 2s;`
      document.body.appendChild(c)
      requestAnimationFrame(() => {
        c.style.transform = `translateY(100vh) rotate(${Math.random()*720}deg)`
        c.style.opacity = "0"
      })
      setTimeout(() => c.remove(), 2200)
    }
  }
}
