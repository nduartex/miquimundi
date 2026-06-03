import { Controller } from "@hotwired/stimulus"

// Converts UTC kickoff times into the visitor's own timezone, entirely in the
// browser. No server-side timezone detection: the browser already knows its
// zone, so `toLocaleTimeString` (and Intl) render each match in local time.
export default class extends Controller {
  static targets = ["time", "zone"]

  connect() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone

    if (this.hasZoneTarget) {
      this.zoneTarget.textContent = tz || "tu hora local"
    }

    const fmt = new Intl.DateTimeFormat("es", {
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    })

    this.timeTargets.forEach((el) => {
      const date = new Date(el.dataset.utc)
      if (isNaN(date)) return
      el.textContent = fmt.format(date)
      el.title = date.toLocaleString("es", { dateStyle: "full", timeStyle: "short" })
    })
  }
}
