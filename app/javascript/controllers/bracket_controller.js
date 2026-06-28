import { Controller } from "@hotwired/stimulus"

// Pick'em bracket projection. Reads a JSON island describing every knockout
// match (real teams when known, the user's saved scores, real results) and,
// whenever a score changes, propagates each predicted winner into the next
// llave it feeds — and each semifinal loser into the third-place match. Purely
// visual: persistence/scoring stay per real match (handled server-side).
export default class extends Controller {
  static targets = ["data", "slot", "input", "penaltyMine", "penaltyReal", "verdict", "score", "mineInput",
    "node", "champion", "championLabel", "stage", "scroller", "zoomLabel", "links", "teamRow", "modeMine", "modeReal"]

  connect() {
    this.matches = JSON.parse(this.dataTarget.textContent)
    this.bySlot = {}
    this.slotOfNumber = {}
    this.matches.forEach((m) => { this.bySlot[m.slot] = m; this.slotOfNumber[m.n] = m.slot })

    // Where each match's winner (and each semi loser) flows next.
    this.winnerFeed = {}
    this.loserFeed = {}
    this.matches.forEach((m) => {
      if (m.advances_to) {
        const side = this.sideFedBy(m.advances_to, `Gan. ${m.n}`)
        if (side) this.winnerFeed[m.slot] = { slot: m.advances_to, side }
      }
    })
    this.matches.forEach((t) => { // third place: labels "Perd. N"
      ["home", "away"].forEach((side) => {
        const lbl = side === "home" ? t.home_label : t.away_label
        const mm = (lbl || "").match(/Perd\.\s*(\d+)/)
        if (mm) this.loserFeed[this.slotOfNumber[+mm[1]]] = { slot: t.slot, side }
      })
    })

    this.scale = 1
    this.mode = "mine"
    this.recalc()
    this.applyModeChrome()
    this.setupViewport()
  }

  // ---- mode: Mi pronóstico ⇄ Real ------------------------------------------
  showMine() { this.setMode("mine") }
  showReal() { this.setMode("real") }

  setMode(mode) {
    if (this.mode === mode) return
    this.mode = mode
    this.applyModeChrome()
    this.recalc()
    this.drawLinks()
  }

  // Toggles the chrome that doesn't depend on the per-match recompute: the two
  // mode buttons, the prediction-only inputs/penalty pickers and verdict lines,
  // and the real-only penalty footnotes.
  applyModeChrome() {
    const mine = this.mode === "mine"
    if (this.hasModeMineTarget) this.styleToggle(this.modeMineTarget, mine)
    if (this.hasModeRealTarget) this.styleToggle(this.modeRealTarget, !mine)
    this.penaltyMineTargets.forEach((s) => s.classList.toggle("hidden", !mine))
    this.verdictTargets.forEach((p) => p.classList.toggle("hidden", !mine))
    this.penaltyRealTargets.forEach((p) => p.classList.toggle("hidden", mine))
    if (this.hasChampionLabelTarget) this.championLabelTarget.textContent = mine ? "Tu campeón" : "Campeón"
  }

  styleToggle(btn, active) {
    btn.classList.toggle("bg-gold", active)
    btn.classList.toggle("text-pitch-900", active)
    btn.classList.toggle("text-white/70", !active)
  }

  disconnect() {
    if (this.io) this.io.disconnect()
    if (this.onResize) window.removeEventListener("resize", this.onResize)
    if (this.scrollerTarget && this.onPointerUp) {
      window.removeEventListener("pointerup", this.onPointerUp)
      window.removeEventListener("pointercancel", this.onPointerUp)
    }
  }

  // ---- viewport: zoom + pinch + pan ----------------------------------------
  // CSS `zoom` scales the layout box (so the scroll container's bars follow),
  // letting one-finger drag pan natively. Two fingers pinch-zoom around their
  // midpoint. On phones we open at a readable size and pan, not fit-to-tiny.
  setupViewport() {
    if (!this.hasStageTarget || !this.hasScrollerTarget) return
    this.pointers = new Map()
    this.pinch = null
    const sc = this.scrollerTarget

    // First paint: the panel starts hidden (width 0), so wait until visible.
    this.io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) this.fitForViewport()
    })
    this.io.observe(this.element)
    this.onResize = () => this.fitForViewport()
    window.addEventListener("resize", this.onResize)

    sc.addEventListener("pointerdown", (e) => this.onPointerDown(e))
    sc.addEventListener("pointermove", (e) => this.onPointerMove(e), { passive: false })
    this.onPointerUp = (e) => this.handlePointerUp(e)
    window.addEventListener("pointerup", this.onPointerUp)
    window.addEventListener("pointercancel", this.onPointerUp)
    sc.addEventListener("wheel", (e) => this.onWheel(e), { passive: false })
  }

  // The cuadro is wider than the screen, so a normal vertical wheel can't reach
  // its sides. Translate the wheel into horizontal scroll while there's room to
  // move; at either end, let the event bubble so the page scrolls as usual.
  onWheel(e) {
    const sc = this.scrollerTarget
    const maxLeft = sc.scrollWidth - sc.clientWidth
    if (maxLeft <= 1) return // nothing to scroll horizontally → page scrolls
    const delta = Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY
    if (delta === 0) return
    if ((delta < 0 && sc.scrollLeft <= 0) || (delta > 0 && sc.scrollLeft >= maxLeft - 1)) return
    sc.scrollLeft += delta
    e.preventDefault()
  }

  isMobile() { return window.matchMedia("(max-width: 639px)").matches }

  // Desktop: fit the whole cuadro to the width. Mobile: open readable and let
  // the user pan/pinch (fitting everything would make text microscopic).
  fitForViewport() {
    if (this.isMobile()) {
      this.applyZoom(this.scale && this.scale !== 1 ? this.scale : 0.85)
      this.scrollerTarget.scrollLeft = 0
    } else {
      this.zoomFit()
    }
    this.drawLinks()
  }

  // Elbow connectors from each match to the llave its winner feeds (and each
  // semi loser to the third-place match). Drawn from the cards' real positions
  // so they stay correct whatever the heights are. Coordinates are normalised
  // by the known zoom factor, then the in-stage SVG re-applies CSS zoom — so a
  // line at layout X lands exactly where its card does.
  drawLinks() {
    if (!this.hasLinksTarget || !this.hasStageTarget) return
    const sr = this.stageTarget.getBoundingClientRect()
    const z = this.scale || 1
    if (sr.width <= 0) return
    const W = sr.width / z, H = sr.height / z
    const svg = this.linksTarget
    svg.setAttribute("viewBox", `0 0 ${W} ${H}`)
    const loc = (slot) => {
      const el = this.nodeTargets.find((n) => n.dataset.slot === slot)
      if (!el) return null
      const r = el.getBoundingClientRect()
      return { x: (r.left - sr.left) / z, y: (r.top - sr.top) / z, w: r.width / z, h: r.height / z }
    }
    const d = []
    const link = (childSlot, parentSlot) => {
      const c = loc(childSlot), p = loc(parentSlot)
      if (!c || !p) return
      const pRight = p.x > c.x
      const sx = c.x + (pRight ? c.w : 0)
      const sy = c.y + c.h / 2
      const ex = p.x + (pRight ? 0 : p.w)
      const ey = p.y + p.h / 2
      const mx = (sx + ex) / 2
      d.push(`M${sx} ${sy} H${mx} V${ey} H${ex}`)
    }
    Object.entries(this.winnerFeed).forEach(([child, f]) => link(child, f.slot))
    Object.entries(this.loserFeed).forEach(([child, f]) => link(child, f.slot))

    svg.replaceChildren()
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    path.setAttribute("d", d.join(" "))
    path.setAttribute("fill", "none")
    path.setAttribute("stroke", "rgba(255,255,255,0.22)")
    path.setAttribute("stroke-width", "1.5")
    path.setAttribute("vector-effect", "non-scaling-stroke")
    svg.appendChild(path)
  }

  zoomFit() {
    if (!this.hasStageTarget || !this.hasScrollerTarget) return
    this.stageTarget.style.zoom = 1
    const natural = this.stageTarget.scrollWidth
    const avail = this.scrollerTarget.clientWidth - 4
    if (avail <= 0 || natural <= 0) { this.stageTarget.style.zoom = this.scale || 1; return }
    this.applyZoom(Math.min(1, avail / natural))
    this.scrollerTarget.scrollLeft = 0
  }

  zoomIn() { this.zoomAround(Math.min(1.6, (this.scale || 1) + 0.15)) }
  zoomOut() { this.zoomAround(Math.max(0.3, (this.scale || 1) - 0.15)) }

  // Zoom keeping the screen point (fx, fy) anchored. Defaults to the scroller
  // centre. Uses scroll-size ratios so it works regardless of the zoom value.
  zoomAround(z, fx, fy) {
    const sc = this.scrollerTarget
    const rect = sc.getBoundingClientRect()
    const cx = fx == null ? rect.width / 2 : fx - rect.left
    const cy = fy == null ? rect.height / 2 : fy - rect.top
    const beforeW = sc.scrollWidth, beforeH = sc.scrollHeight
    const fracX = beforeW ? (sc.scrollLeft + cx) / beforeW : 0
    const fracY = beforeH ? (sc.scrollTop + cy) / beforeH : 0
    this.applyZoom(z)
    sc.scrollLeft = fracX * sc.scrollWidth - cx
    sc.scrollTop = fracY * sc.scrollHeight - cy
  }

  applyZoom(z) {
    this.scale = Math.max(0.3, Math.min(1.6, z))
    this.stageTarget.style.zoom = this.scale
    if (this.hasZoomLabelTarget) this.zoomLabelTarget.textContent = `${Math.round(this.scale * 100)}%`
    this.drawLinks()
  }

  onPointerDown(e) {
    if (e.pointerType !== "touch") return
    this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY })
    if (this.pointers.size === 2) {
      const [a, b] = [...this.pointers.values()]
      this.pinch = { dist: this.dist(a, b), zoom: this.scale }
      this.scrollerTarget.style.touchAction = "none" // take over the gesture
    }
  }

  onPointerMove(e) {
    if (!this.pointers.has(e.pointerId)) return
    this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY })
    if (this.pinch && this.pointers.size >= 2) {
      e.preventDefault()
      const [a, b] = [...this.pointers.values()]
      const d = this.dist(a, b)
      if (this.pinch.dist > 0) {
        this.zoomAround(this.pinch.zoom * (d / this.pinch.dist), (a.x + b.x) / 2, (a.y + b.y) / 2)
      }
    }
  }

  handlePointerUp(e) {
    this.pointers.delete(e.pointerId)
    if (this.pointers.size < 2 && this.pinch) {
      this.pinch = null
      this.scrollerTarget.style.touchAction = "" // back to native pan
    }
  }

  dist(a, b) { return Math.hypot(a.x - b.x, a.y - b.y) }

  // Which side of match `slot` is fed by `label` (e.g. "Gan. 73").
  sideFedBy(slot, label) {
    const t = this.bySlot[slot]
    if (!t) return null
    if (t.home_label === label) return "home"
    if (t.away_label === label) return "away"
    return null
  }

  // Repaints the whole bracket for the active mode. "mine" projects the user's
  // picks forward (their winner advances); "real" shows only the teams/results
  // the DB actually recorded.
  recalc() {
    const mine = this.mode === "mine"
    const resolved = {} // mine mode only: `${slot}-${side}` -> projected team
    const teamAt = (slot, side) => {
      const m = this.bySlot[slot]
      const real = side === "home" ? m.home : m.away
      if (!mine) return real // real mode: DB truth only
      return real || resolved[`${slot}-${side}`] || null
    }

    this.matches.forEach((m) => {
      const home = teamAt(m.slot, "home")
      const away = teamAt(m.slot, "away")
      this.paintSlot(m.slot, "home", home)
      this.paintSlot(m.slot, "away", away)
      this.setScore(m, "home")
      this.setScore(m, "away")
      if (mine) this.updatePenalty(m, home, away)

      const { winner, loser } = this.decideWinner(m, home, away, mine)
      this.highlightWinner(m, winner, home, away)

      if (mine) {
        const wf = this.winnerFeed[m.slot]
        if (wf && winner && !(this.bySlot[wf.slot][wf.side])) resolved[`${wf.slot}-${wf.side}`] = winner
        const lf = this.loserFeed[m.slot]
        if (lf && loser && !(this.bySlot[lf.slot][lf.side])) resolved[`${lf.slot}-${lf.side}`] = loser
      }
    })

    this.paintChampion(resolved, mine)
  }

  // The winning/losing team of a match: real result in real mode; the user's
  // predicted scores (+ penalty pick on a tie) in prediction mode.
  decideWinner(m, home, away, mine) {
    let side = null
    if (!mine) {
      side = this.realWinnerSide(m)
    } else {
      const ph = this.pred(m, "home"), pa = this.pred(m, "away")
      if (ph != null && pa != null) {
        if (ph > pa) side = "home"
        else if (pa > ph) side = "away"
        else {
          const pen = this.penaltyPick(m)
          if (pen && home && away) side = pen === String(home.id) ? "home" : pen === String(away.id) ? "away" : null
        }
      }
    }
    if (!side) return { winner: null, loser: null }
    return side === "home" ? { winner: home, loser: away } : { winner: away, loser: home }
  }

  // Fills a side's score badge from the active mode's data, and toggles the
  // editable stepper (prediction mode) against the read-only number.
  setScore(m, side) {
    const span = this.scoreTargets.find((s) => s.dataset.slot === m.slot && s.dataset.side === side)
    const input = this.mineInputTargets.find((i) => i.dataset.slot === m.slot && i.dataset.side === side)
    const mine = this.mode === "mine"
    if (mine && input) {
      input.classList.remove("hidden")
      if (span) span.classList.add("hidden")
      return
    }
    if (input) input.classList.add("hidden")
    if (!span) return
    span.classList.remove("hidden")
    const v = mine ? span.dataset.mine : span.dataset.real
    span.textContent = v === "" || v == null ? "·" : v
  }

  // Marks your projected winner of a match: a crown + a bigger, gold name, with
  // the other side dimmed — so your favourite to advance pops out. Cleared when
  // there's no pick yet.
  highlightWinner(m, winner, home, away) {
    const winSide = winner ? (home && winner.id === home.id ? "home" : away && winner.id === away.id ? "away" : null) : null
    this.teamRowTargets
      .filter((r) => r.dataset.slot === m.slot)
      .forEach((row) => {
        const slot = row.querySelector('[data-bracket-target="slot"]')
        const crown = row.querySelector('[data-bracket-target="crown"]')
        const isWin = winSide != null && row.dataset.side === winSide
        if (crown) crown.classList.toggle("hidden", !isWin)
        if (slot) {
          slot.style.color = isWin ? "var(--color-gold)" : ""
          slot.style.fontWeight = isWin ? "800" : ""
          slot.style.fontSize = isWin ? "0.875rem" : ""
        }
        row.style.opacity = winSide != null && !isWin ? "0.5" : ""
      })
  }

  // Keeps each match's penalty dropdown in sync with its two teams (real or
  // projected from upstream picks), so a tie can be broken in every round — not
  // just where the teams happen to be known server-side. Rebuilds only when the
  // pair changes, preserving the current/saved pick when still valid.
  updatePenalty(m, home, away) {
    const sel = this.penaltyMineTargets.find((s) => s.dataset.slot === m.slot)
    if (!sel) return
    const sig = `${home ? home.id : ""}|${away ? away.id : ""}`
    if (sel.dataset.teams === sig) return
    sel.dataset.teams = sig
    const current = sel.value || (m.penalty_qualifier_id != null ? String(m.penalty_qualifier_id) : "")
    const add = (val, label) => {
      const o = document.createElement("option")
      o.value = val
      o.textContent = label
      sel.appendChild(o)
    }
    sel.replaceChildren()
    add("", "Penales: —")
    if (home) add(String(home.id), home.name)
    if (away) add(String(away.id), away.name)
    sel.value = [...sel.options].some((o) => o.value === current) ? current : ""
  }

  realWinnerSide(m) {
    if (m.real_home == null || m.real_away == null) return null
    if (m.real_home > m.real_away) return "home"
    if (m.real_away > m.real_home) return "away"
    if (m.penalty_winner_id && m.home) return m.penalty_winner_id === m.home.id ? "home" : "away"
    return null
  }

  // Predicted goals for a side: live input when editable, else saved value.
  pred(m, side) {
    const input = this.inputTargets.find((el) => el.dataset.slot === m.slot && el.dataset.side === side)
    if (input) { const v = parseInt(input.value, 10); return Number.isNaN(v) ? null : v }
    const v = side === "home" ? m.pred_home : m.pred_away
    return v == null ? null : v
  }

  penaltyPick(m) {
    const sel = this.penaltyMineTargets.find((el) => el.dataset.slot === m.slot)
    if (sel) return sel.value || null
    return m.penalty_qualifier_id ? String(m.penalty_qualifier_id) : null
  }

  // Renders a slot's team (real or projected). Built via the DOM API (no
  // innerHTML) so names/urls are never parsed as markup. When no team is known,
  // shows the seed label (mine) or "Por definir" (real).
  paintSlot(slot, side, team) {
    const m = this.bySlot[slot]
    const el = this.slotTargets.find((s) => s.dataset.slot === slot && s.dataset.side === side)
    if (!el) return
    el.replaceChildren()
    const name = document.createElement("span")
    name.className = "truncate"
    if (team) {
      if (team.flag) {
        const img = document.createElement("img")
        img.src = team.flag
        img.alt = ""
        img.className = "w-[20px] h-[14px] rounded-sm object-cover ring-1 ring-white/15 shrink-0"
        el.appendChild(img)
      }
      name.textContent = team.name
    } else {
      name.classList.add("text-white/40")
      name.textContent = this.mode === "real" ? "Por definir" : (side === "home" ? m.home_label : m.away_label)
    }
    el.appendChild(name)
  }

  paintChampion(resolved, mine) {
    if (!this.hasChampionTarget) return
    const finalM = this.matches.find((m) => m.phase === "final")
    if (!finalM) return
    // Reuse decideWinner so a final settled on penalties (a tie + a penalty
    // pick) crowns the champion just like a decisive score does.
    const home = finalM.home || resolved[`${finalM.slot}-home`]
    const away = finalM.away || resolved[`${finalM.slot}-away`]
    const { winner } = this.decideWinner(finalM, home, away, mine)
    this.championTarget.textContent = winner ? winner.name : "—"
  }
}
