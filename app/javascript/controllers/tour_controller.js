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
  static values = { name: String, steps: Array, auto: Boolean, markUrl: String }

  connect() {
    this.onReposition = () => this.position()
    // Auto-start: account-based when `auto` is provided by the server,
    // otherwise fall back to the per-browser localStorage flag.
    const auto = this.hasAutoValue ? this.autoValue : !this.completed
    if (this.steps.length && auto) {
      setTimeout(() => this.start(), 350) // let layout/fonts settle
    }
  }

  disconnect() { this.teardown() }

  get steps() { return this.stepsValue || [] }
  get storageKey() { return `tour:${this.nameValue}` }
  get completed() {
    try { return localStorage.getItem(this.storageKey) === "done" } catch { return false }
  }

  // Public action — replay the tour anytime (ignores any "seen" flag).
  restart() { this.teardown(); this.start() }

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
    // Pin fixed inline so the .surface rules (which set position) can never
    // knock the tooltip out of fixed positioning via the cascade.
    this.tooltip.style.position = "fixed"
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
    this.reveal()
  }

  move(delta) {
    const n = this.i + delta
    if (n >= this.steps.length) return this.finish()
    if (n < 0) return
    this.i = n
    this.render()
  }

  // Scroll once, on entering a step, so the target AND its tooltip sit centred
  // as one unit (otherwise centring only the target leaves the card cramped at a
  // screen edge). The scroll/resize handler then only repositions, never scrolls.
  reveal() {
    const step = this.steps[this.i]
    const target = step && document.querySelector(step.el)
    if (!target) { this.finish(); return }

    const margin = 12
    const gap = 14
    const tipW = Math.min(320, window.innerWidth - 24)
    this.tooltip.style.width = `${tipW}px`
    this.tooltip.style.maxHeight = ""
    this.tooltip.style.overflowY = ""

    const r = target.getBoundingClientRect()
    const tipH = this.tooltip.offsetHeight
    const blockH = r.height + gap + tipH
    // Centre the (target + tooltip) block when it fits; otherwise pin the target
    // near the top so the tall tooltip has the rest of the screen below it.
    const desiredTop = blockH <= window.innerHeight - 2 * margin
      ? (window.innerHeight - blockH) / 2
      : margin * 2
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    window.scrollTo({
      top: Math.max(0, r.top + window.scrollY - desiredTop),
      behavior: reduce ? "auto" : "smooth"
    })
    this.position()
  }

  position() {
    const step = this.steps[this.i]
    const target = step && document.querySelector(step.el)
    if (!target) { this.finish(); return }
    const r = target.getBoundingClientRect()
    const pad = 8
    Object.assign(this.highlight.style, {
      top: `${r.top - pad}px`, left: `${r.left - pad}px`,
      width: `${r.width + pad * 2}px`, height: `${r.height + pad * 2}px`
    })
    // Tooltip: prefer below the target, else above, using its REAL height so it
    // never overlaps the highlighted element or runs off-screen.
    const gap = 14
    const margin = 12
    const tipW = Math.min(320, window.innerWidth - 24)
    this.tooltip.style.width = `${tipW}px`
    this.tooltip.style.opacity = "1"
    this.tooltip.style.left = `${Math.max(margin, Math.min(r.left, window.innerWidth - tipW - margin))}px`

    // Reset any height cap from a previous step before measuring.
    this.tooltip.style.maxHeight = ""
    this.tooltip.style.overflowY = ""

    const tipH = this.tooltip.offsetHeight
    const spaceBelow = window.innerHeight - r.bottom - gap
    const spaceAbove = r.top - gap

    let top
    if (tipH <= spaceBelow) {
      top = r.bottom + gap            // fits below
    } else if (tipH <= spaceAbove) {
      top = r.top - gap - tipH        // fits above
    } else if (spaceBelow >= spaceAbove) {
      // Doesn't fully fit anywhere: sit just below the target and scroll inside,
      // so the card never crosses into the highlighted (gold) area.
      top = r.bottom + gap
      this.tooltip.style.maxHeight = `${Math.max(80, spaceBelow - margin)}px`
      this.tooltip.style.overflowY = "auto"
    } else {
      // More room above: pin near the top edge, capped so its bottom stays clear
      // of the highlight, and scroll inside.
      top = margin
      this.tooltip.style.maxHeight = `${Math.max(80, spaceAbove - margin)}px`
      this.tooltip.style.overflowY = "auto"
    }
    this.tooltip.style.bottom = "auto"
    this.tooltip.style.top = `${Math.max(margin, top)}px`
  }

  finish() {
    try { localStorage.setItem(this.storageKey, "done") } catch { /* ignore */ }
    if (this.markUrlValue) {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      fetch(this.markUrlValue, {
        method: "PATCH",
        headers: token ? { "X-CSRF-Token": token } : {},
        credentials: "same-origin"
      }).catch(() => {})
    }
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
