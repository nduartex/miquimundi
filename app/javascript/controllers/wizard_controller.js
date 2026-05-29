import { Controller } from "@hotwired/stimulus"

// Multi-step wizard with animated crossfade/slide transitions and a
// progress indicator. Steps: Grupos (0) -> Eliminatorias (1) -> Premios (2).
export default class extends Controller {
  static targets = ["panel", "tab", "back", "forward", "submit"]

  connect() {
    this.index = 0
    this.render()
  }

  go(event) {
    this.transitionTo(Number(event.params.step))
  }

  next() {
    if (this.index < this.panelTargets.length - 1) this.transitionTo(this.index + 1)
  }

  prev() {
    if (this.index > 0) this.transitionTo(this.index - 1)
  }

  transitionTo(i) {
    if (i === this.index) return
    this.index = i
    this.render()
    const panel = this.panelTargets[i]
    panel.classList.add("is-enter")
    requestAnimationFrame(() => requestAnimationFrame(() => panel.classList.remove("is-enter")))
    this.element.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  render() {
    this.panelTargets.forEach((p, i) => (p.hidden = i !== this.index))
    this.tabTargets.forEach((t, i) => t.setAttribute("aria-current", i === this.index ? "true" : "false"))

    const last = this.panelTargets.length - 1
    if (this.hasBackTarget) this.backTarget.disabled = this.index === 0
    // Next hides on the last step; Save stays available on every step.
    if (this.hasForwardTarget) this.forwardTarget.classList.toggle("hidden", this.index === last)
  }
}
