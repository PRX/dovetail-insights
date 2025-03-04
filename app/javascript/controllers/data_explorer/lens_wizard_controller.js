import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  // Show the wizard if no lens selection is present in the URL
  connect() {
    const params = new URLSearchParams(window.location.search);
    if (!params.has("lens")) {
      this.element.showModal();
    }
  }
}
