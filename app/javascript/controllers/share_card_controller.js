import { Controller } from "@hotwired/stimulus"

// Draws a 9:16 "Mi predicción" card on a canvas (no network → no canvas tainting),
// sized for Instagram / WhatsApp Stories. Reads the prediction data embedded as
// JSON in the `data` target. On mobile it shares via the Web Share API; on desktop
// it reveals an inline preview + download link instead of a jarring file-open popup.
const GOLD = "#ffc531"
const GOLD_SOFT = "#ffd766"
const WHITE = "#eafff1"
const DIM = "rgba(234,255,241,0.55)"
const DIMMER = "rgba(234,255,241,0.45)"
const COND = "'Barlow Condensed', sans-serif"
const SANS = "'Barlow', sans-serif"

export default class extends Controller {
  static targets = ["data", "preview", "image", "download"]

  async share() {
    const blob = await this.draw()
    const file = new File([blob], "mi-prediccion-mundial.png", { type: "image/png" })
    const text = "Mi predicción para el Mundial 2026 🏆"

    // Always reveal the preview so the card is visible (and shareable) on desktop.
    if (this._url) URL.revokeObjectURL(this._url)
    this._url = URL.createObjectURL(blob)
    if (this.hasImageTarget) this.imageTarget.src = this._url
    if (this.hasDownloadTarget) this.downloadTarget.href = this._url
    if (this.hasPreviewTarget) this.previewTarget.classList.remove("hidden")

    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      try {
        await navigator.share({ files: [file], title: "Mi Predicción Mundial", text })
      } catch { /* user cancelled */ }
    }
  }

  get data() {
    return JSON.parse(this.dataTarget.textContent)
  }

  async draw() {
    // Wait for web fonts so the canvas doesn't render with fallback faces.
    if (document.fonts && document.fonts.ready) {
      try { await document.fonts.ready } catch { /* ignore */ }
    }

    const d = this.data
    const W = 1080, H = 1920
    const cv = document.createElement("canvas")
    cv.width = W; cv.height = H
    const ctx = cv.getContext("2d")

    // Background: vertical green gradient + soft gold glow + inset frame.
    const bg = ctx.createLinearGradient(0, 0, 0, H)
    bg.addColorStop(0, "#0d5129"); bg.addColorStop(0.55, "#0a3a1e"); bg.addColorStop(1, "#062414")
    ctx.fillStyle = bg; ctx.fillRect(0, 0, W, H)
    const glow = ctx.createRadialGradient(W / 2, 360, 80, W / 2, 360, 620)
    glow.addColorStop(0, "rgba(255,197,49,0.16)"); glow.addColorStop(1, "rgba(255,197,49,0)")
    ctx.fillStyle = glow; ctx.fillRect(0, 0, W, H)
    ctx.strokeStyle = "rgba(234,255,241,0.22)"; ctx.lineWidth = 5
    this.roundRect(ctx, 32, 32, W - 64, H - 64, 44); ctx.stroke()

    // Header.
    ctx.textAlign = "center"
    ctx.fillStyle = GOLD; ctx.font = `900 74px ${COND}`
    ctx.fillText(d.title || "MI PREDICCIÓN", W / 2, 165)
    ctx.fillStyle = WHITE; ctx.font = `700 42px ${SANS}`
    // Center the username itself (like the title); the flag rides as a trailing
    // accent so the readable name stays dead-centre regardless of emoji width.
    const name = d.username || ""
    ctx.fillText(name, W / 2, 230)
    if (d.userFlag) {
      ctx.textAlign = "left"
      ctx.fillText(d.userFlag, W / 2 + ctx.measureText(name).width / 2 + 14, 230)
      ctx.textAlign = "center"
    }
    ctx.fillStyle = DIM; ctx.font = `700 28px ${COND}`
    ctx.fillText("M U N D I A L   2 0 2 6", W / 2, 276)

    // Section: groups (2 columns × up to 6 rows).
    this.sectionLabel(ctx, "Pasan de grupos", 372)
    const COL_X = [64, 556], COL_W = 456, GROUP_STEP = 58, GROUP_Y = 445
    ;(d.groups || []).forEach((g, i) => {
      const x = COL_X[i % 2]
      const y = GROUP_Y + Math.floor(i / 2) * GROUP_STEP
      this.drawSegments(ctx, this.groupSegments(g), x, y, COL_W, 30)
    })

    // Section: best thirds — two columns sharing the same left edges as the
    // groups above, with a dim bullet so each pick reads as one tidy list.
    this.sectionLabel(ctx, "Mejores terceros", 818)
    const THIRD_STEP = 56, THIRD_Y = 885
    ;(d.thirds || []).forEach((t, i) => {
      const cx = COL_X[i % 2] + COL_W / 2
      const y = THIRD_Y + Math.floor(i / 2) * THIRD_STEP
      this.drawSegments(ctx, [
        { t: "•  ", c: GOLD },
        { t: this.teamLabel(t), c: WHITE }
      ], cx, y, COL_W, 30, SANS, "center")
    })

    // Section: awards — a clean label→value table on a single shared left edge,
    // no separator hairlines, so the rows line up quietly instead of competing.
    this.sectionLabel(ctx, "Premios", 1140)
    const AWARD_STEP = 74, AWARD_Y = 1212
    const ROW_MAXW = W - 192
    ;(d.awards || []).forEach((a, i) => {
      const y = AWARD_Y + i * AWARD_STEP
      const val = [a.name, a.flag].filter(Boolean).join(" ")
      this.drawSegments(ctx, [
        { t: a.label, c: WHITE },
        { t: " :  ", c: GOLD, bold: true },
        { t: val, c: WHITE }
      ], W / 2, y, ROW_MAXW, 32, SANS, "center")
    })

    // Footer.
    ctx.textAlign = "center"; ctx.fillStyle = DIMMER; ctx.font = `700 30px ${COND}`
    ctx.fillText("miquimundi", W / 2, 1700)

    return new Promise((resolve) => cv.toBlob(resolve, "image/png"))
  }

  sectionLabel(ctx, text, y) {
    ctx.textAlign = "center"; ctx.fillStyle = GOLD; ctx.font = `800 34px ${COND}`
    ctx.fillText(text.toUpperCase(), 540, y)
  }

  teamLabel(t) {
    if (!t) return "—"
    return [t.name, t.flag].filter(Boolean).join(" ")
  }

  groupSegments(g) {
    return [
      { t: `${g.name}  `, c: GOLD_SOFT, bold: true },
      { t: "1. ", c: GOLD },
      { t: this.teamLabel(g.first), c: WHITE },
      { t: "  ·  ", c: DIM },
      { t: "2. ", c: GOLD },
      { t: this.teamLabel(g.second), c: WHITE }
    ]
  }

  // Draw left-aligned coloured segments on one line, shrinking the font until the
  // whole line fits maxWidth (so full country names never overflow the column).
  // align "left" (default): `x` is the left edge. "center": `x` is the centre
  // point and the whole line is laid out symmetrically around it.
  drawSegments(ctx, segs, x, y, maxWidth, baseSize, family = SANS, align = "left") {
    const weightOf = (s) => (s.bold ? "900" : "700")
    const measure = (size) => segs.reduce((w, s) => {
      ctx.font = `${weightOf(s)} ${size}px ${family}`
      return w + ctx.measureText(s.t).width
    }, 0)
    let size = baseSize
    while (size > 22 && measure(size) > maxWidth) size -= 2

    ctx.textAlign = "left"
    let cx = align === "center" ? x - measure(size) / 2 : x
    for (const s of segs) {
      ctx.font = `${weightOf(s)} ${size}px ${family}`
      ctx.fillStyle = s.c
      ctx.fillText(s.t, cx, y)
      cx += ctx.measureText(s.t).width
    }
  }

  // Shrink the current font so `text` fits maxWidth (sets ctx.font as side effect).
  fitFont(ctx, text, maxWidth, baseSize, weight, family) {
    let size = baseSize
    do {
      ctx.font = `${weight} ${size}px ${family}`
      size -= 2
    } while (size > 22 && ctx.measureText(text).width > maxWidth)
  }

  roundRect(ctx, x, y, w, h, r) {
    const radius = Math.min(r, w / 2, h / 2)
    ctx.beginPath()
    ctx.moveTo(x + radius, y)
    ctx.arcTo(x + w, y, x + w, y + h, radius)
    ctx.arcTo(x + w, y + h, x, y + h, radius)
    ctx.arcTo(x, y + h, x, y, radius)
    ctx.arcTo(x, y, x + w, y, radius)
    ctx.closePath()
  }
}
