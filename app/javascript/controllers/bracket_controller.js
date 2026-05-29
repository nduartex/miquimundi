import { Controller } from "@hotwired/stimulus"

// Live predicted-bracket engine. Resolves every knockout slot from the user's
// own predictions and propagates winners up to the champion.
//   - "1A"/"2B"  -> nth team of a group (from the group-order ranking)
//   - "3º A/.."   -> 3rd of a chosen candidate group
//   - "Gan. 73"   -> winner of match 73 (derived from its score / penalty pick)
//   - "Perd. 101" -> loser of match 101
// Recomputes on any input change or when the group ordering broadcasts.
export default class extends Controller {
  static values = { data: Object }
  static targets = ["champion"]

  connect() {
    this.matches = this.dataValue.matches || []
    this.teams = this.dataValue.teams || {}
    this.groups = this.dataValue.groups || {}
    this.byNumber = Object.fromEntries(this.matches.map((m) => [m.n, m]))

    this.scheduled = false
    this.onChange = () => this.schedule()
    this.element.addEventListener("input", this.onChange)
    this.element.addEventListener("change", this.onChange)
    this.boundBracket = () => this.schedule()
    window.addEventListener("bracket:changed", this.boundBracket)
    this.recompute()
  }

  disconnect() {
    window.removeEventListener("bracket:changed", this.boundBracket)
  }

  schedule() {
    if (this.scheduled) return
    this.scheduled = true
    requestAnimationFrame(() => { this.scheduled = false; this.recompute() })
  }

  // ---- resolution -------------------------------------------------------
  recompute() {
    const W = {}, L = {}, H = {}, A = {}
    for (const m of this.matches) {
      const home = this.resolveSide(m, "home", W, L)
      const away = this.resolveSide(m, "away", W, L)
      H[m.n] = home; A[m.n] = away
      const { win, los } = this.outcome(m, home, away)
      W[m.n] = win; L[m.n] = los
    }
    this.render(H, A, W)
  }

  resolveSide(m, side, W, L) {
    const f = m[side]
    switch (f.kind) {
      case "pos":    return this.ranking(f.group)[f.pos - 1] || null
      case "third": { const g = this.thirdChoice(m); return g ? (this.ranking(g)[2] || null) : null }
      case "winner": return W[f.match] || null
      case "loser":  return L[f.match] || null
      default:       return null
    }
  }

  outcome(m, home, away) {
    if (home == null || away == null) return { win: null, los: null }
    const h = this.score(m, "pred_home"), a = this.score(m, "pred_away")
    if (h == null || a == null) return { win: null, los: null }
    if (h > a) return { win: home, los: away }
    if (a > h) return { win: away, los: home }
    const pk = this.input(m, "penalty_qualifier_id")?.value
    if (pk && String(pk) === String(home)) return { win: home, los: away }
    if (pk && String(pk) === String(away)) return { win: away, los: home }
    return { win: null, los: null }
  }

  ranking(letter) {
    const g = this.groups[letter]
    if (!g) return []
    const ids = []
    for (const slot of ["first", "second", "third", "fourth"]) {
      const inp = this.element.querySelector(`[name="group_predictions[${g.id}][${slot}_team_id]"]`)
      if (inp && inp.value) ids.push(String(inp.value))
    }
    for (const id of g.teams) if (!ids.includes(String(id))) ids.push(String(id))
    return ids.slice(0, 4)
  }

  thirdChoice(m) { return this.input(m, "third_group")?.value || null }
  score(m, field) { const v = this.input(m, field)?.value; return v === "" || v == null ? null : parseInt(v, 10) }
  input(m, field) { return this.element.querySelector(`[name="match_predictions[${m.id}][${field}]"]`) }

  // ---- rendering --------------------------------------------------------
  render(H, A, W) {
    for (const m of this.matches) {
      this.renderSlot(m, "home", H[m.n])
      this.renderSlot(m, "away", A[m.n])
      this.renderPenalty(m, H[m.n], A[m.n])
    }
    this.renderChampion(W[104])
  }

  renderSlot(m, side, teamId) {
    const el = this.matchEl(m)?.querySelector(`[data-slot="${side}"]`)
    if (!el) return
    if (teamId) el.innerHTML = this.teamChip(teamId)
    else el.textContent = el.dataset.label || ""
  }

  renderPenalty(m, home, away) {
    const wrap = this.matchEl(m)?.querySelector("[data-penalty]")
    if (!wrap) return
    const h = this.score(m, "pred_home"), a = this.score(m, "pred_away")
    const tie = home && away && h != null && a != null && h === a
    wrap.hidden = !tie
    if (!tie) return
    const sel = wrap.querySelector("select")
    const want = `${home}|${away}`
    if (sel.dataset.pair !== want) {
      const current = sel.value || sel.dataset.initial || ""
      sel.dataset.pair = want
      sel.innerHTML =
        `<option value="">¿Quién pasa por penales?</option>` +
        [home, away].map((id) => `<option value="${id}">${esc(this.name(id))}</option>`).join("")
      if (String(current) === String(home) || String(current) === String(away)) sel.value = String(current)
    }
  }

  renderChampion(teamId) {
    if (!this.hasChampionTarget) return
    if (teamId) this.championTarget.innerHTML = `🏆 ${this.teamChip(teamId)}`
    else this.championTarget.innerHTML = `<span class="text-white/40">Tu campeón aparecerá aquí</span>`
  }

  // ---- helpers ----------------------------------------------------------
  matchEl(m) {
    this._cache ||= {}
    return (this._cache[m.n] ||= this.element.querySelector(`[data-bracket-match="${m.n}"]`))
  }

  name(id) { return this.teams[String(id)]?.name || "" }

  teamChip(id) {
    const t = this.teams[String(id)]
    if (!t) return ""
    const flag = t.flag ? `<img src="${t.flag}" alt="" class="w-[22px] h-[16px] rounded-sm object-cover ring-1 ring-white/15 shrink-0">` : ""
    return `<span class="inline-flex items-center gap-1.5 min-w-0">${flag}<span class="truncate">${esc(t.name)}</span></span>`
  }
}

function esc(s) {
  const d = document.createElement("div")
  d.textContent = s == null ? "" : String(s)
  return d.innerHTML
}
