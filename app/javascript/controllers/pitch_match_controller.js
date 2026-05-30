import { Controller } from "@hotwired/stimulus"

// Ambient background "match": 11 v 11 dots (one colour per team) playing a
// loose game of football behind the UI. Fluid steering movement, several random
// attack patterns (tiki-taka, long ball, wing + cross, counter, through ball,
// dribble), shots on goal with keeper saves, goals, and a centre kickoff for the
// conceding team. Pure canvas, behind everything, ignores pointer events, pauses
// when hidden, respects prefers-reduced-motion.
export default class extends Controller {
  connect() {
    this.canvas = document.createElement("canvas")
    this.canvas.setAttribute("aria-hidden", "true")
    Object.assign(this.canvas.style, {
      position: "fixed", inset: "0", width: "100%", height: "100%",
      zIndex: "-1", pointerEvents: "none"
    })
    document.body.prepend(this.canvas)
    this.ctx = this.canvas.getContext("2d")

    // One distinct uniform colour per team.
    this.teams = [
      { color: "rgba(56, 189, 248, 0.66)", ring: "rgba(186, 240, 255, 0.6)" }, // sky
      { color: "rgba(255, 93, 125, 0.66)", ring: "rgba(255, 205, 215, 0.6)" }  // rose
    ]
    this.score = [0, 0]
    this.flash = 0

    // Pitch geometry as fractions of the play area, from real proportions
    // (105×68 m). Single source of truth shared by drawing AND goal logic.
    this.GEO = {
      goalHalf: 0.075,   // half goal-mouth height (mouth ≈ 7.3m / 68m, enlarged a touch to read)
      goalDepth: 0.02,   // how far the net sits behind the line
      sixHalf: 0.16,     // goal area (6-yd box) half height
      sixDepth: 0.05,    // goal area depth
      penHalf: 0.30,     // penalty area half height
      penDepth: 0.15,    // penalty area depth
      penSpot: 0.11,     // penalty spot distance from goal line
      arcR: 0.09         // penalty arc radius ("the D")
    }

    this.buildPlayers()
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    this.onResize = () => this.resize()
    this.onVisibility = () => { document.hidden ? this.stop() : this.run() }
    window.addEventListener("resize", this.onResize)
    document.addEventListener("visibilitychange", this.onVisibility)

    this.resize()
    this.kickoff(Math.random() < 0.5 ? 0 : 1)
    if (this.reduced) { this.draw() } else { this.run() }
  }

  disconnect() {
    this.stop()
    window.removeEventListener("resize", this.onResize)
    document.removeEventListener("visibilitychange", this.onVisibility)
    this.canvas?.remove()
  }

  // 4-3-3 per team in its own half. Team 0 attacks toward x=1, team 1 toward x=0.
  buildPlayers() {
    const shape = [
      [0.05, 0.50],                                            // GK
      [0.18, 0.22], [0.18, 0.40], [0.18, 0.60], [0.18, 0.78],  // DEF
      [0.33, 0.32], [0.33, 0.50], [0.33, 0.68],                // MID
      [0.46, 0.26], [0.46, 0.50], [0.46, 0.74]                 // FWD
    ]
    this.players = []
    for (let team = 0; team < 2; team++) {
      shape.forEach(([hx, hy], idx) => {
        const homeX = team === 0 ? hx : 1 - hx
        this.players.push({
          team, idx, gk: idx === 0,
          homeX, homeY: hy,
          x: homeX, y: hy, vx: 0, vy: 0,
          jx: Math.random() * 6.28, jy: Math.random() * 6.28 // wander phase
        })
      })
    }
  }

  attackDir(team) { return team === 0 ? 1 : -1 }
  goalX(team) { return team === 0 ? 1 : 0 }   // goal this team attacks

  kickoff(team) {
    // Conceding team restarts from the centre circle.
    for (const p of this.players) { p.x = p.homeX; p.y = p.homeY; p.vx = p.vy = 0 }
    const mid = this.players.find(pl => pl.team === team && pl.idx === 6)
    this.ball = { x: 0.5, y: 0.5, owner: null, target: null, team, mode: "carry", shot: false }
    this.ball.owner = mid
    mid.x = 0.5; mid.y = 0.5
    this.pattern = this.pickPattern()
    this.holdUntil = (this.time || 0) + 1.0
    this.nextReceiver = null
    this.planNext()
  }

  pickPattern() {
    // Weighted grab-bag of football attack styles.
    const bag = [
      "tiki", "tiki", "tiki",   // short possession (common)
      "wing", "wing",           // down the flank then cross
      "through",                // ball into space behind defence
      "counter",                // fast vertical break
      "longball",               // direct long pass to a forward
      "dribble"                 // carry it forward solo
    ]
    return bag[(Math.random() * bag.length) | 0]
  }

  // Decide what the current carrier does next (pass target, dribble, or shot).
  planNext() {
    const carrier = this.ball.owner
    if (!carrier) return
    const dir = this.attackDir(carrier.team)
    const gx = this.goalX(carrier.team)
    const distToGoal = Math.abs(gx - carrier.x)
    const mates = this.players.filter(p => p.team === carrier.team && p !== carrier)

    // Shot chance grows close to goal; long-range pot-shots are rarer.
    const inBox = distToGoal < 0.22
    const shootChance = inBox ? 0.55 : distToGoal < 0.4 ? 0.14 : 0.02
    if (Math.random() < shootChance) { this.scheduleShot(carrier); return }

    // Turnover: occasional interception flips possession.
    if (Math.random() < 0.12) {
      const opp = this.nearestOpponent(carrier)
      if (opp) { this.queuePass(opp, 0.2 + Math.random() * 0.3); this.ball.team = opp.team; return }
    }

    // Pattern-specific receiver pick.
    let pick
    switch (this.pattern) {
      case "longball": {
        const fwd = mates.filter(p => p.idx >= 8)
        pick = this.rand(fwd) || this.mostForward(mates, dir)
        break
      }
      case "counter": {
        pick = this.mostForward(mates, dir, 0.5)
        break
      }
      case "through": {
        // teammate ahead of the carrier, prefer central
        const ahead = mates.filter(p => (dir > 0 ? p.x > carrier.x : p.x < carrier.x))
        pick = this.rand(ahead) || this.mostForward(mates, dir)
        break
      }
      case "wing": {
        // push to the widest forward, then a central striker (cross)
        const wide = mates.filter(p => p.idx >= 8).sort((a, b) =>
          Math.abs(0.5 - b.y) - Math.abs(0.5 - a.y))[0]
        pick = wide || this.mostForward(mates, dir)
        break
      }
      case "dribble": {
        // sometimes just carry forward instead of passing
        if (distToGoal > 0.18 && Math.random() < 0.6) { this.scheduleDribble(carrier); return }
        pick = this.bestForward(mates, dir)
        break
      }
      default: { // tiki: short, nearby, slightly forward
        const near = mates
          .map(p => ({ p, d: Math.hypot(p.x - carrier.x, p.y - carrier.y) }))
          .filter(o => o.d < 0.32)
          .sort((a, b) => a.d - b.d)
        pick = (near[(Math.random() * Math.min(3, near.length)) | 0] || {}).p
            || this.bestForward(mates, dir)
      }
    }
    if (!pick) pick = this.rand(mates)
    const dist = Math.hypot(pick.x - carrier.x, pick.y - carrier.y)
    this.queuePass(pick, 0.9 + dist * (this.pattern === "tiki" ? 2.6 : 3.8))
  }

  scheduleDribble(carrier) {
    // Carry the ball toward goal for a short burst, then re-plan.
    this.ball.mode = "carry"
    const dir = this.attackDir(carrier.team)
    carrier.dribbleX = Math.max(0.04, Math.min(0.96, carrier.x + dir * (0.1 + Math.random() * 0.1)))
    carrier.dribbleY = Math.max(0.1, Math.min(0.9, carrier.y + (Math.random() - 0.5) * 0.18))
    this.holdUntil = this.time + 1.1 + Math.random() * 0.9
    this.replanAfterHold = true
  }

  scheduleShot(carrier) {
    // Hold briefly, then strike toward the goal mouth (with placement error).
    this.holdUntil = this.time + 0.4 + Math.random() * 0.4
    this.pendingShot = carrier
  }

  fireShot(carrier) {
    const gx = this.goalX(carrier.team)
    const gh = this.GEO.goalHalf
    // Placement scatters a bit WIDER than the posts, so some shots clearly miss.
    const aim = 0.5 + (Math.random() - 0.5) * (gh * 2 * 2.1)
    this.ball.owner = null
    this.ball.mode = "shot"
    this.ball.shot = true
    this.ball.team = carrier.team
    this.ball.from = { x: carrier.x, y: carrier.y }
    // Ball flies to the goal line; if wide it ends just past the post line.
    this.ball.to = { x: gx, y: aim }
    this.ball.t = 0
    this.ball.dur = 0.7 + Math.abs(gx - carrier.x) * 1.4

    // Outcome is tied to where the ball actually goes:
    //  - outside the posts  → wide miss (never a goal)
    //  - between the posts  → keeper may save, otherwise goal
    const keeper = this.players.find(p => p.gk && p.team !== carrier.team)
    const onTarget = Math.abs(aim - 0.5) <= gh
    const save = onTarget && Math.random() < 0.5
    this.ball.outcome = !onTarget ? "miss" : save ? "save" : "goal"
    this.ball.keeper = keeper
    this.ball.aim = aim
  }

  resolveShot() {
    const b = this.ball
    if (b.outcome === "goal") {
      this.score[b.team]++
      this.flash = 1
      this.goalGlow = { x: b.to.x, y: b.to.y, team: b.team }
      this.kickoff(b.team === 0 ? 1 : 0) // conceding team restarts
    } else {
      // miss/save → other team plays it out from the back
      const recover = b.outcome === "save" ? b.keeper
        : this.players.find(p => p.gk && p.team !== b.team)
      this.ball.owner = recover
      this.ball.team = recover.team
      this.ball.mode = "carry"
      this.ball.shot = false
      this.pattern = this.pickPattern()
      this.holdUntil = this.time + 0.8 + Math.random() * 0.7
      this.planNext()
    }
  }

  queuePass(receiver, dur) {
    this.nextReceiver = receiver
    this.passDur = Math.max(0.4, dur)
  }

  startPass() {
    const r = this.nextReceiver
    this.ball.from = { x: this.ball.x, y: this.ball.y }
    this.ball.target = r
    this.ball.mode = "pass"
    this.ball.owner = null
    this.ball.t = 0
    this.ball.dur = this.passDur
    this.nextReceiver = null
  }

  // helpers
  rand(arr) { return arr.length ? arr[(Math.random() * arr.length) | 0] : null }
  mostForward(mates, dir, minAdvance = 0) {
    let best = null, bs = -Infinity
    for (const p of mates) {
      const f = dir > 0 ? p.x : 1 - p.x
      if (f < minAdvance) continue
      if (f > bs) { bs = f; best = p }
    }
    return best || this.rand(mates)
  }
  bestForward(mates, dir) {
    let best = null, bs = -Infinity
    for (const p of mates) {
      const f = dir > 0 ? p.x : 1 - p.x
      const s = f + Math.random() * 0.5
      if (s > bs) { bs = s; best = p }
    }
    return best
  }
  nearestOpponent(p) {
    let best = null, bd = Infinity
    for (const o of this.players) {
      if (o.team === p.team || o.gk) continue
      const d = Math.hypot(o.x - p.x, o.y - p.y)
      if (d < bd) { bd = d; best = o }
    }
    return best
  }

  resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2)
    this.w = window.innerWidth
    this.h = window.innerHeight
    this.canvas.width = Math.floor(this.w * dpr)
    this.canvas.height = Math.floor(this.h * dpr)
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    if (this.reduced) this.draw()
  }

  run() {
    if (this.raf || this.reduced) return
    this.last = performance.now()
    const tick = (now) => {
      const dt = Math.min((now - this.last) / 1000, 0.05)
      this.last = now
      this.update(dt)
      this.draw()
      this.raf = requestAnimationFrame(tick)
    }
    this.raf = requestAnimationFrame(tick)
  }

  stop() { if (this.raf) { cancelAnimationFrame(this.raf); this.raf = null } }

  update(dt) {
    this.time = (this.time || 0) + dt
    if (this.flash > 0) this.flash = Math.max(0, this.flash - dt * 0.8)

    const posTeam = this.ball.owner ? this.ball.owner.team : this.ball.team

    // ---- Player steering (smooth: target → accel → velocity → damping) ----
    for (const p of this.players) {
      p.jx += dt * 0.35; p.jy += dt * 0.45
      let tx = p.homeX + Math.sin(p.jx) * (p.gk ? 0.005 : 0.02)
      let ty = p.homeY + Math.sin(p.jy) * (p.gk ? 0.07 : 0.03)

      if (p.gk) {
        // keeper hugs its line, tracks the ball vertically within the goal mouth
        const gh = this.GEO.goalHalf
        tx = p.homeX
        ty = 0.5 + Math.max(-gh, Math.min(gh, (this.ball.y - 0.5) * 0.8))
      } else if (this.ball.owner === p) {
        // carrier moves toward its dribble target / drifts goalward
        const gx = this.goalX(p.team)
        tx = p.dribbleX != null ? p.dribbleX : tx * 0.7 + gx * 0.3 * 0.18 + p.x * 0.55
        ty = p.dribbleY != null ? p.dribbleY : ty
      } else {
        // team shape slides up when attacking, drops when defending
        const dir = this.attackDir(p.team)
        const push = p.idx >= 8 ? 0.17 : p.idx >= 5 ? 0.11 : 0.05
        const shift = posTeam === p.team ? push : -push * 0.5
        tx += dir * shift
        // attackers/mids on the ball-team gravitate slightly toward the ball lane
        if (posTeam === p.team && p.idx >= 5) ty = ty * 0.8 + this.ball.y * 0.2
      }

      tx = Math.max(0.02, Math.min(0.98, tx))
      ty = Math.max(0.04, Math.min(0.96, ty))

      // steering with capped acceleration — soft spring + heavy damping for
      // calm, gliding motion (not twitchy)
      const ax = (tx - p.x) * 3.2 - p.vx * 3.4
      const ay = (ty - p.y) * 3.2 - p.vy * 3.4
      p.vx += ax * dt; p.vy += ay * dt
      const sp = Math.hypot(p.vx, p.vy)
      const max = this.ball.owner === p ? 0.16 : 0.12
      if (sp > max) { p.vx = p.vx / sp * max; p.vy = p.vy / sp * max }
      p.x += p.vx * dt; p.y += p.vy * dt
    }

    // ---- Ball logic ----
    const b = this.ball
    if (b.mode === "carry" && b.owner) {
      b.x = b.owner.x; b.y = b.owner.y
      if (this.time >= this.holdUntil) {
        if (this.pendingShot) { const s = this.pendingShot; this.pendingShot = null; this.fireShot(s) }
        else if (this.replanAfterHold) {
          this.replanAfterHold = false
          if (b.owner) { b.owner.dribbleX = b.owner.dribbleY = null }
          this.planNext()
          if (this.nextReceiver) this.startPass()
        } else if (this.nextReceiver) {
          if (b.owner) { b.owner.dribbleX = b.owner.dribbleY = null }
          this.startPass()
        }
      }
    } else if (b.mode === "pass") {
      b.t += dt / b.dur
      const k = Math.min(1, b.t)
      const e = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2
      b.x = b.from.x + (b.target.x - b.from.x) * e
      b.y = b.from.y + (b.target.y - b.from.y) * e
      if (k >= 1) {
        b.owner = b.target; b.team = b.target.team; b.mode = "carry"
        this.holdUntil = this.time + 0.6 + Math.random() * 0.8
        this.planNext()
      }
    } else if (b.mode === "shot") {
      b.t += dt / b.dur
      const k = Math.min(1, b.t)
      const e = 1 - Math.pow(1 - k, 2) // accelerate toward goal
      b.x = b.from.x + (b.to.x - b.from.x) * e
      b.y = b.from.y + (b.to.y - b.from.y) * e
      if (k >= 1) this.resolveShot()
    }
  }

  draw() {
    const ctx = this.ctx
    ctx.clearRect(0, 0, this.w, this.h)

    const mx = this.w * 0.06, my = this.h * 0.08
    const pw = this.w - mx * 2, ph = this.h - my * 2
    const X = nx => mx + nx * pw
    const Y = ny => my + ny * ph

    // Full pitch markings + corner flags
    this.drawField(mx, my, pw, ph, X, Y)

    // Goals — mouth height matches GEO.goalHalf so the posts line up exactly
    // with the goal logic (a shot is only a goal between these posts).
    const goalH = ph * (this.GEO.goalHalf * 2)
    const goalD = Math.max(10, pw * this.GEO.goalDepth)
    const gy0 = Y(0.5) - goalH / 2
    this.drawGoal(X(0), gy0, -goalD, goalH)
    this.drawGoal(X(1), gy0, goalD, goalH)

    // Goal celebration glow
    if (this.flash > 0 && this.goalGlow) {
      ctx.save()
      ctx.globalAlpha = this.flash * 0.5
      const g = ctx.createRadialGradient(X(this.goalGlow.x), Y(this.goalGlow.y), 4,
                                         X(this.goalGlow.x), Y(this.goalGlow.y), 160)
      const c = this.teams[this.goalGlow.team].color
      g.addColorStop(0, c); g.addColorStop(1, "rgba(255,255,255,0)")
      ctx.fillStyle = g
      ctx.fillRect(0, 0, this.w, this.h)
      ctx.restore()
    }

    // Players (carrier gets a faint highlight ring)
    for (const p of this.players) {
      const t = this.teams[p.team]
      const x = X(p.x), y = Y(p.y)
      if (this.ball.owner === p) {
        ctx.beginPath(); ctx.arc(x, y, 9, 0, 6.2832)
        ctx.strokeStyle = "rgba(255,255,255,0.35)"; ctx.lineWidth = 1.5; ctx.stroke()
      }
      ctx.beginPath(); ctx.arc(x, y, p.gk ? 6 : 5.5, 0, 6.2832)
      ctx.fillStyle = t.color; ctx.fill()
      ctx.lineWidth = 1.5; ctx.strokeStyle = t.ring; ctx.stroke()
    }

    // Ball
    const bx = X(this.ball.x), by = Y(this.ball.y)
    ctx.save()
    ctx.shadowColor = "rgba(255,255,255,0.9)"; ctx.shadowBlur = 8
    ctx.beginPath(); ctx.arc(bx, by, 3.6, 0, 6.2832)
    ctx.fillStyle = "rgba(255,255,255,0.96)"; ctx.fill()
    ctx.restore()
  }

  // Full chalk markings: boundary, halfway line + centre circle, penalty &
  // goal areas, penalty spots/arcs, and corner arcs with little corner flags.
  drawField(mx, my, pw, ph, X, Y) {
    const ctx = this.ctx
    const line = "rgba(234, 255, 241, 0.18)"
    ctx.save()
    ctx.strokeStyle = line
    ctx.lineWidth = 1.5

    // Outer boundary
    ctx.strokeRect(mx, my, pw, ph)

    // Halfway line
    ctx.beginPath(); ctx.moveTo(X(0.5), my); ctx.lineTo(X(0.5), my + ph); ctx.stroke()

    // Centre circle + spot
    const cr = Math.min(pw, ph) * 0.12
    ctx.beginPath(); ctx.arc(X(0.5), Y(0.5), cr, 0, 6.2832); ctx.stroke()
    this.dot(X(0.5), Y(0.5), line)

    // Penalty + goal areas, spots and arcs, mirrored on each side — sizes from
    // GEO so they share the same proportions as the goal/scoring logic.
    const G = this.GEO
    const boxW = pw * G.penDepth,  boxH = ph * (G.penHalf * 2)  // penalty area
    const sixW = pw * G.sixDepth,  sixH = ph * (G.sixHalf * 2)  // goal area
    const spot = pw * G.penSpot                                  // penalty spot
    const arcR = pw * G.arcR
    for (const side of [0, 1]) {
      const gl = side === 0 ? mx : mx + pw          // goal line x
      const sgn = side === 0 ? 1 : -1               // into the pitch
      // penalty area
      ctx.strokeRect(side === 0 ? gl : gl - boxW, Y(0.5) - boxH / 2, boxW, boxH)
      // goal area
      ctx.strokeRect(side === 0 ? gl : gl - sixW, Y(0.5) - sixH / 2, sixW, sixH)
      // penalty spot
      const sx = gl + sgn * spot
      this.dot(sx, Y(0.5), line)
      // penalty arc: show only the segment that pokes out past the box edge
      const boxEdge = gl + sgn * boxW
      const cos = Math.min(1, Math.abs(boxEdge - sx) / arcR)
      const ang = Math.acos(cos)                    // half-sweep outside the box
      const base = side === 0 ? 0 : Math.PI         // facing into the pitch
      ctx.beginPath(); ctx.arc(sx, Y(0.5), arcR, base - ang, base + ang); ctx.stroke()
    }

    // Corner arcs + flags at the four corners
    const cq = Math.min(pw, ph) * 0.02
    const corners = [
      [mx, my, 0], [mx + pw, my, 1], [mx, my + ph, 2], [mx + pw, my + ph, 3]
    ]
    for (const [cx, cy, q] of corners) {
      const start = [0, Math.PI / 2, -Math.PI / 2, Math.PI][q]
      ctx.beginPath(); ctx.arc(cx, cy, cq, start, start + Math.PI / 2); ctx.stroke()
      this.drawCornerFlag(cx, cy, q)
    }

    ctx.restore()
  }

  dot(x, y, color) {
    const ctx = this.ctx
    ctx.save(); ctx.fillStyle = color
    ctx.beginPath(); ctx.arc(x, y, 1.6, 0, 6.2832); ctx.fill(); ctx.restore()
  }

  // Small corner flag: a thin pole leaning outward with a triangular pennant.
  drawCornerFlag(cx, cy, q) {
    const ctx = this.ctx
    const left = q === 0 || q === 2
    const top = q === 0 || q === 1
    const dx = left ? -1 : 1
    const dy = top ? -1 : 1
    const poleH = Math.min(this.w, this.h) * 0.02
    const px = cx + dx * 2
    const topY = cy + dy * 2
    const botY = topY - dy * poleH
    ctx.save()
    // pole
    ctx.strokeStyle = "rgba(255,255,255,0.7)"; ctx.lineWidth = 1.5
    ctx.beginPath(); ctx.moveTo(px, topY); ctx.lineTo(px, botY); ctx.stroke()
    // pennant
    ctx.fillStyle = "rgba(255, 197, 49, 0.9)" // trophy gold
    ctx.beginPath()
    ctx.moveTo(px, botY)
    ctx.lineTo(px + dx * poleH * 0.8, botY + dy * poleH * 0.22)
    ctx.lineTo(px, botY + dy * poleH * 0.45)
    ctx.closePath(); ctx.fill()
    ctx.restore()
  }

  drawGoal(x, y, d, h) {
    const ctx = this.ctx
    ctx.save()
    ctx.strokeStyle = "rgba(234, 255, 241, 0.16)"; ctx.lineWidth = 1
    const cells = 5
    for (let i = 0; i <= cells; i++) {
      const yy = y + (h / cells) * i
      ctx.beginPath(); ctx.moveTo(x, yy); ctx.lineTo(x + d, yy); ctx.stroke()
    }
    for (let i = 0; i <= cells; i++) {
      const xx = x + (d / cells) * i
      ctx.beginPath(); ctx.moveTo(xx, y); ctx.lineTo(xx, y + h); ctx.stroke()
    }
    ctx.strokeStyle = "rgba(255, 255, 255, 0.85)"; ctx.lineWidth = 2.5
    ctx.beginPath()
    ctx.moveTo(x, y); ctx.lineTo(x, y + h)
    ctx.moveTo(x, y); ctx.lineTo(x + d, y)
    ctx.moveTo(x, y + h); ctx.lineTo(x + d, y + h)
    ctx.moveTo(x + d, y); ctx.lineTo(x + d, y + h)
    ctx.stroke()
    ctx.restore()
  }
}
