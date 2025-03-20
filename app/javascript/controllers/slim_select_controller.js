import { Controller } from "@hotwired/stimulus";
import SlimSelect from "slim-select";

export default class extends Controller {
  connect() {
    this.slim = new SlimSelect({
      select: this.element,
      settings: {
        placeholderText: "",
        showSearch: this.showSearch,
      },
      events: {
        afterChange: (val) => {
          if (val.length > 0) {
            this.slim.selectEl.classList.remove("form-control-blank");
          } else {
            this.slim.selectEl.classList.add("form-control-blank");
          }
          this.element.dispatchEvent(new Event("blur"));
        },
      },
    });
  }

  disconnect() {
    this.slim.destroy();
  }

  get showSearch() {
    return this.element.children.length > 10;
  }
}
