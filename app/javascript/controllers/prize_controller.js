import { Controller } from "@hotwired/stimulus"

// Shows the prize-pot field only when "liga con premio" is checked.
export default class extends Controller {
  static targets = ["toggle", "fields"]

  connect() { this.update() }

  update() {
    this.fieldsTarget.hidden = !this.toggleTarget.checked
  }
}
