import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  go(event) {
    const step = Number(event.params.step)
    this.panelTargets.forEach((p, i) => p.classList.toggle("hidden", i !== step))
  }
}
