import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["root"];

  toggle() {
    this.rootTarget.classList.toggle("nochrome");
  }
}
