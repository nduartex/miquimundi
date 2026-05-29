import { Controller } from "@hotwired/stimulus"

// Lightweight first-visit guided tour (no external library).
// Renders a dimmed backdrop, a spotlight around each target element, and a
// tooltip with Saltar / Atrás / Siguiente. Skippable; completion is stored in
// localStorage so it only auto-runs once per tour name. Respects reduced-motion.
//
// Usage:
//   data-controller="tour"
//   data-tour-name-value="mi-quiniela"
//   data-tour-steps-value='[{"el":"#id","title":"…","body":"…"}]'
export default class extends Controller {
  static values = { name: String, steps: Array }

  connect() {
    this.onReposition = () => this.position()
    if (this.steps.length && !this.completed) {
      // wait a tick so the layout (and fonts) settle before measuring
      setTimeout(() => this.start(), 350)
    }
  }

  disconnect() { this.teardown() }

  get steps() { return this.stepsValue || [] }
  get storageKey() { return `tour:${this.nameValue}` }
  get completed() {
    try { return localStorage.getItem(this.storageKey) === "done" } catch { return false }
  }

  start() {
    this.i = 0
    this.build()
    this.render()
    window.addEventListener("resize", this.onReposition)
    window.addEventListener("scroll", this.onReposition, true)
    this.onKey = (e) => { if (e.key === "Escape") this.finish() }
    window.addEventListener("keydown", this.onKey)
  }

  build() {
    this.backdrop = el("div", "tour-backdrop")
    this.highlight = el("div", "tour-highlight")
    this.tooltip = el("div", "tour-tooltip surface p-4 text-white")
    this.tooltip.style.opacity = "0"
    document.body.appendChild(this.backdrop)
    document.body.appendChild(this.highlight)
    document.body.appendChild(this.tooltip)
    this.backdrop.addEventListener("click", () => this.finish())
  }

  render() {
    const step = this.steps[this.i]
    const last = this.i === this.steps.length - 1
    this.tooltip.innerHTML = `
      <div class="text-xs uppercase tracking-wide text-white/50 mb-1">Paso ${this.i + 1} de ${this.steps.length}</div>
      <h3 class="font-display text-xl font-bold text-amber-300 mb-1">${esc(step.title)}</h3>
      <p class="text-white/85 text-sm leading-relaxed mb-4">${esc(step.body)}</p>
      <div class="flex items-center justify-between gap-2">
        <button type="button" data-tour-action="skip" class="text-white/50 hover:text-white text-sm font-semibold px-2 py-2 cursor-pointer">Saltar</button>
        <div class="flex gap-2">
          ${this.i > 0 ? `<button type="button" data-tour-action="back" class="px-4 py-2 rounded-lg bg-white/10 hover:bg-white/20 text-white text-sm font-semibold cursor-pointer">Atrás</button>` : ""}
          <button type="button" data-tour-action="next" class="px-4 py-2 rounded-lg bg-amber-400 hover:brightness-110 text-slate-900 text-sm font-bold cursor-pointer">${last ? "Entendido" : "Siguiente"}</button>
        </div>
      </div>`
    this.tooltip.querySelectorAll("[data-tour-action]").forEach((b) => {
      b.addEventListener("click", (e) => {
        e.stopPropagation()
        const a = b.dataset.tourAction
        if (a === "skip") this.finish()
        else if (a === "back") this.move(-1)
        else this.move(1)
      })
    })
    this.position()
  }

  move(delta) {
    const n = this.i + delta
    if (n >= this.steps.length) return this.finish()
    if (n < 0) return
    this.i = n
    this.render()
  }

  position() {
    const step = this.steps[this.i]
    const target = step && document.querySelector(step.el)
    if (!target) { this.finish(); return }
    target.scrollIntoView({ behavior: "smooth", block: "center" })
    const r = target.getBoundingClientRect()
    const pad = 8
    Object.assign(this.highlight.style, {
      top: `${r.top - pad}px`, left: `${r.left - pad}px`,
      width: `${r.width + pad * 2}px`, height: `${r.height + pad * 2}px`
    })
    // place tooltip below the target if room, else above; clamp horizontally
    const tipW = Math.min(320, window.innerWidth - 24)
    const below = r.bottom + 16
    const wantAbove = below + 180 > window.innerHeight
    let left = Math.max(12, Math.min(r.left, window.innerWidth - tipW - 12))
    this.tooltip.style.width = `${tipW}px`
    this.tooltip.style.left = `${left}px`
    this.tooltip.style.opacity = "1"
    if (wantAbove) {
      this.tooltip.style.top = "auto"
      this.tooltip.style.bottom = `${window.innerHeight - r.top + 16}px`
    } else {
      this.tooltip.style.bottom = "auto"
      this.tooltip.style.top = `${below}px`
    }
  }

  finish() {
    try { localStorage.setItem(this.storageKey, "done") } catch { /* ignore */ }
    this.teardown()
  }

  teardown() {
    window.removeEventListener("resize", this.onReposition)
    window.removeEventListener("scroll", this.onReposition, true)
    if (this.onKey) window.removeEventListener("keydown", this.onKey)
    ;[this.backdrop, this.highlight, this.tooltip].forEach((n) => n && n.remove())
    this.backdrop = this.highlight = this.tooltip = null
  }
}

function el(tag, className) {
  const n = document.createElement(tag)
  n.className = className
  return n
}

function esc(s) {
  const d = document.createElement("div")
  d.textContent = s == null ? "" : String(s)
  return d.innerHTML
}
