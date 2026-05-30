import { Controller } from "@hotwired/stimulus"

// Disables the "Guardar" button until the first part (Grupos + Terceros + Premios)
// is fully marked, and shows what's missing. The server is the source of truth;
// this is UX sugar. No-op when enforce is false (e.g. after kickoff the group
// stage is locked and saves only carry knockout predictions).
export default class extends Controller {
  static targets = ["submit", "status"]
  static values = { enforce: Boolean }

  connect() {
    this.refresh()
  }

  refresh() {
    if (!this.enforceValue) return
    const missing = this.missing()
    const ok = missing.length === 0
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = !ok
      this.submitTarget.classList.toggle("opacity-40", !ok)
      this.submitTarget.classList.toggle("cursor-not-allowed", !ok)
    }
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = ok ? "" : `Falta: ${missing.join(" · ")}`
      this.statusTarget.hidden = ok
    }
  }

  missing() {
    const out = []

    const thirds = this.element.querySelectorAll(
      'input[name="best_third_groups[]"]:checked'
    ).length
    if (thirds !== 8) out.push(`${Math.max(8 - thirds, 0)} terceros`)

    const awardFields = [
      "balon_oro_player_id", "bota_oro_player_id", "guante_oro_player_id",
      "young_player_id", "fair_play_team_id",
    ]
    const awardsLeft = awardFields.filter((f) => {
      const el = this.element.querySelector(`[name="award_prediction[${f}]"]`)
      return !el || !el.value
    }).length
    if (awardsLeft > 0) out.push(`${awardsLeft} premios`)

    const groupsIncomplete = Array.from(
      this.element.querySelectorAll('[name$="[first_team_id]"]')
    ).some((first) => !first.value)
    if (groupsIncomplete) out.push("ordenar grupos")

    return out
  }
}
