import { Controller } from "@hotwired/stimulus";
import SlimSelect from "slim-select";

export default class extends Controller {
  static values = {
    asyncSearchEnabled: Boolean,
    asyncSearchEndpointPath: String,
  };

  // Setup the SlimSelect instance
  connect() {
    this.slim = new SlimSelect({
      select: this.element,
      settings: this.settings,
      events: {
        search: this.asyncSearchEnabledValue
          ? this.asyncSearch.bind(this)
          : null,
      },
    });
  }

  disconnect() {
    this.slim.destroy();
  }

  // Provides default settings for the SlimSelect instance, and allows each
  // setting to be overridden by a data attribute on the select element, using
  // the form `data-ss-opt-<optionName>`, such as
  // `data-ss-opt-closeOnSelect="true"`.
  get settings() {
    const settings = {
      placeholderText: "Select…",
      showSearch: this.showSearch,
      closeOnSelect: false,
      allowDeselect: true,
    };

    Object.keys(this.element.dataset).forEach((key) => {
      if (key.startsWith("ss-opt-")) {
        // For an element with `data-ss-opt-allowDeselect="foo"`…
        // key will be `ssOptAllowDeselect`

        // Transform `ssOptAllowDeselect` to `allowDeselect`
        const optKey = key[5].toLowerCase() + key.slice(6);

        const optValue = this.element.dataset[key];

        if (optValue === "true") {
          settings[optKey] = true;
        } else if (optValue === "false") {
          settings[optKey] = false;
        } else {
          settings[optKey] = optValue;
        }
      }
    });

    return settings;
  }

  get showSearch() {
    return this.asyncSearchEnabledValue || this.element.children.length > 10;
  }

  // https://slimselectjs.com/events#search
  asyncSearch(search, currentData) {
    return new Promise((resolve, reject) => {
      fetch(
        `${this.asyncSearchEndpointPathValue}?q=${encodeURIComponent(search)}`,
        {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
          },
        },
      )
        .then((response) => response.json())
        .then((data) => {
          const options = data.map((opt) => {
            return {
              text: opt.t2,
              value: opt.t1,
            };
          });
          resolve(options);
        });
    });
  }
}
