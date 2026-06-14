import { Controller } from "@hotwired/stimulus"

// "8 best thirds" picker. Shows each group's current 3rd-place team (reactive
// to the group ordering) and enforces selecting exactly `max` (8).
export default class extends Controller {
  static values = { teams: Object, groups: Object, max: { type: Number, default: 8 }, locked: Boolean }
  static targets = ["checkbox", "option", "counter"]

  connect() {
    this.onGroups = () => this.refreshTeams()
    window.addEventListener("bracket:changed", this.onGroups)
    this.refreshTeams()
    this.enforce()
  }

  disconnect() { window.removeEventListener("bracket:changed", this.onGroups) }

  change() { this.enforce() }

  get selected() { return this.checkboxTargets.filter((c) => c.checked) }

  enforce() {
    const n = this.selected.length
    // Update every counter (desktop inline + mobile sticky pill).
    this.counterTargets.forEach((c) => { c.textContent = `${n}/${this.maxValue}` })
    const full = n >= this.maxValue
    // When locked (read-only/shared views) the checkboxes are disabled server-side
    // and must stay that way — don't re-enable the checked ones.
    if (!this.lockedValue) {
      this.checkboxTargets.forEach((c) => { c.disabled = full && !c.checked })
    }
    this.optionTargets.forEach((opt) => {
      const cb = opt.querySelector('input[type="checkbox"]')
      // El borde dorado señala una selección aún editable. En vistas guardadas
      // (locked) la elección es definitiva: conservamos el check pero quitamos
      // el borde para que no parezca modificable.
      const ring = cb.checked && !this.lockedValue
      opt.classList.toggle("ring-2", ring)
      opt.classList.toggle("ring-amber-300", ring)
      opt.classList.toggle("opacity-40", cb.disabled && !cb.checked)
    })
  }

  refreshTeams() {
    this.optionTargets.forEach((opt) => {
      const gid = this.groupsValue[opt.dataset.group]
      const inp = document.querySelector(`[name="group_predictions[${gid}][third_team_id]"]`)
      // Locked/read-only views have no group-order fields; the 3rd-place team is
      // rendered server-side, so leave it untouched instead of blanking it.
      if (!inp) return
      const team = inp.value ? this.teamsValue[inp.value] : null
      const disp = opt.querySelector("[data-team]")
      if (!disp) return
      if (team) {
        const flag = team.flag
          ? `<img src="${team.flag}" alt="" class="w-[22px] h-[16px] rounded-sm object-cover ring-1 ring-white/15">`
          : ""
        disp.innerHTML = `<span class="inline-flex items-center gap-1.5">${flag}<span>${esc(team.name)}</span></span>`
      } else {
        disp.textContent = "—"
      }
    })
  }
}

function esc(s) {
  const d = document.createElement("div")
  d.textContent = s == null ? "" : String(s)
  return d.innerHTML
}
