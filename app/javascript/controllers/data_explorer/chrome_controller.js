import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["root"];

  toggle() {
    if (document.querySelector("#results table")) {
      this.rootTarget.classList.toggle("nochrome");
    }
  }
}
