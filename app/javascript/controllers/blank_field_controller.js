import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  // eslint-disable-next-line class-methods-use-this
  blur(event) {
    if (event.target.value) {
      event.target.classList.remove("form-control-blank");
    } else {
      event.target.classList.add("form-control-blank");
    }
  }
}
