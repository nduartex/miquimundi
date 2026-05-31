import { Controller } from "@hotwired/stimulus"

// Draws a summary card on a canvas (no network → no canvas tainting) and shares
// it via the Web Share API (WhatsApp/Stories on mobile); falls back to a PNG
// download on desktop/unsupported browsers.
export default class extends Controller {
  static values = {
    username: String, flag: String, points: Number, exact: Number,
    hits: Number, rank: Number, champion: String, championFlag: String
  }

  async share() {
    const blob = await this.draw()
    const file = new File([blob], "mi-quiniela-mundial.png", { type: "image/png" })
    const text = `Mi quiniela del Mundial: ${this.pointsValue} pts 🏆`
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      try {
        await navigator.share({ files: [file], title: "Mi Quiniela Mundial", text })
      } catch { /* user cancelled */ }
    } else {
      const a = document.createElement("a")
      a.href = URL.createObjectURL(blob)
      a.download = file.name
      a.click()
      URL.revokeObjectURL(a.href)
    }
  }

  draw() {
    const W = 1080, H = 1080
    const cv = document.createElement("canvas")
    cv.width = W; cv.height = H
    const ctx = cv.getContext("2d")
    ctx.fillStyle = "#0a3a1e"; ctx.fillRect(0, 0, W, H)
    ctx.strokeStyle = "rgba(234,255,241,0.25)"; ctx.lineWidth = 6
    ctx.strokeRect(40, 40, W - 80, H - 80)
    ctx.textAlign = "center"
    ctx.fillStyle = "#ffc531"; ctx.font = "900 64px 'Barlow Condensed', sans-serif"
    ctx.fillText("MIQUIMUNDI", W / 2, 170)
    ctx.fillStyle = "#eafff1"; ctx.font = "700 44px 'Barlow', sans-serif"
    ctx.fillText(`${this.flagValue} ${this.usernameValue}`, W / 2, 260)
    ctx.fillStyle = "#ffc531"; ctx.font = "900 260px 'Anton', sans-serif"
    ctx.fillText(String(this.pointsValue), W / 2, 580)
    ctx.fillStyle = "#eafff1"; ctx.font = "700 40px 'Barlow Condensed', sans-serif"
    ctx.fillText("PUNTOS", W / 2, 650)
    ctx.font = "700 40px 'Barlow', sans-serif"
    ctx.fillStyle = "#4ade80"; ctx.fillText(`✓ ${this.exactValue} exactos`, W / 2 - 230, 760)
    ctx.fillStyle = "#ff5d7d"; ctx.fillText(`⚽ ${this.hitsValue} aciertos`, W / 2 + 230, 760)
    ctx.fillStyle = "#38bdf8"; ctx.fillText(`#${this.rankValue} en el ranking`, W / 2, 840)
    if (this.championValue) {
      ctx.fillStyle = "#ffd766"; ctx.font = "700 44px 'Barlow Condensed', sans-serif"
      ctx.fillText(`🏆 Mi campeón: ${this.championFlagValue} ${this.championValue}`, W / 2, 960)
    }
    return new Promise((resolve) => cv.toBlob(resolve, "image/png"))
  }
}
