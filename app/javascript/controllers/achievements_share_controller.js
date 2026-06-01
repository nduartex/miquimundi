import { Controller } from "@hotwired/stimulus"

// Draws a 9:16 "Mis logros" card on a canvas (no network → no tainting), sized
// for Instagram / WhatsApp Stories, listing only the UNLOCKED achievements.
// Reads the data embedded as JSON in the `data` target. On mobile it shares via
// the Web Share API; on desktop it reveals an inline preview + download link.
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
    const file = new File([blob], "mis-logros-mundial.png", { type: "image/png" })
    const text = "Estos son mis logros en el Mundial 2026 🏅"

    if (this._url) URL.revokeObjectURL(this._url)
    this._url = URL.createObjectURL(blob)
    if (this.hasImageTarget) this.imageTarget.src = this._url
    if (this.hasDownloadTarget) this.downloadTarget.href = this._url
    if (this.hasPreviewTarget) this.previewTarget.classList.remove("hidden")

    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      try {
        await navigator.share({ files: [file], title: "Mis logros — Mundial 2026", text })
      } catch { /* user cancelled */ }
    }
  }

  get data() {
    return JSON.parse(this.dataTarget.textContent)
  }

  async draw() {
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
    ctx.fillText(d.title || "MIS LOGROS", W / 2, 165)
    ctx.fillStyle = WHITE; ctx.font = `700 42px ${SANS}`
    const user = [d.username, d.userFlag].filter(Boolean).join(" ")
    ctx.fillText(user, W / 2, 230)
    ctx.fillStyle = DIM; ctx.font = `700 28px ${COND}`
    ctx.fillText("M U N D I A L   2 0 2 6", W / 2, 276)

    // Progress line: "N de M desbloqueados".
    const items = d.achievements || []
    ctx.fillStyle = GOLD_SOFT; ctx.font = `800 34px ${COND}`
    ctx.fillText(`${d.count} DE ${d.total} DESBLOQUEADOS`, W / 2, 348)

    // Achievement cards — one rounded row each, emoji + name + wrapped blurb.
    // Step adapts to the count so a few or many badges both fill the space well.
    const TOP = 430, BOTTOM = 1620
    const n = Math.max(items.length, 1)
    const step = Math.min(240, (BOTTOM - TOP) / n)
    const cardH = Math.min(190, step - 22)
    const X = 80, CARD_W = W - 160

    items.forEach((a, i) => {
      const y = TOP + i * step
      // Card background.
      ctx.fillStyle = "rgba(234,255,241,0.06)"
      ctx.strokeStyle = "rgba(255,197,49,0.35)"; ctx.lineWidth = 2
      this.roundRect(ctx, X, y, CARD_W, cardH, 26); ctx.fill(); ctx.stroke()

      // Emoji badge on the left.
      const cy = y + cardH / 2
      ctx.textAlign = "center"; ctx.textBaseline = "middle"
      ctx.font = `400 84px ${SANS}`
      ctx.fillText(a.emoji || "🏅", X + 90, cy)

      // Name + description on the right.
      ctx.textBaseline = "alphabetic"; ctx.textAlign = "left"
      const tx = X + 180, tw = CARD_W - 180 - 40
      ctx.fillStyle = GOLD; ctx.font = `800 44px ${COND}`
      ctx.fillText((a.name || "").toUpperCase(), tx, cy - 6)
      ctx.fillStyle = DIM; ctx.font = `400 30px ${SANS}`
      this.wrapText(ctx, a.description || "", tx, cy + 32, tw, 36, 2)
    })

    // Footer.
    ctx.textAlign = "center"; ctx.fillStyle = DIMMER; ctx.font = `700 30px ${COND}`
    ctx.fillText("miquimundi", W / 2, 1700)

    return new Promise((resolve) => cv.toBlob(resolve, "image/png"))
  }

  // Draw text wrapped to maxWidth, capping at maxLines (last line gets an ellipsis
  // if it overflows). Returns nothing; purely visual.
  wrapText(ctx, text, x, y, maxWidth, lineHeight, maxLines) {
    const words = text.split(/\s+/)
    const lines = []
    let line = ""
    for (const w of words) {
      const test = line ? `${line} ${w}` : w
      if (ctx.measureText(test).width > maxWidth && line) {
        lines.push(line); line = w
        if (lines.length === maxLines) break
      } else {
        line = test
      }
    }
    if (lines.length < maxLines && line) lines.push(line)
    lines.forEach((ln, i) => {
      let out = ln
      if (i === maxLines - 1 && ctx.measureText(out).width > maxWidth) {
        while (out.length && ctx.measureText(`${out}…`).width > maxWidth) out = out.slice(0, -1)
        out += "…"
      }
      ctx.fillText(out, x, y + i * lineHeight)
    })
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
