import { Controller } from "@hotwired/stimulus";
import SlimSelect from "slim-select";

export default class extends Controller {
  connect() {
    this.slim = new SlimSelect({
      select: this.element,
      settings: {
        placeholderText: "Select…",
        showSearch: this.showSearch,
        closeOnSelect: false,
        allowDeselect: true,
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
