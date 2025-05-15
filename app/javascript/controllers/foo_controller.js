import { Controller } from "@hotwired/stimulus";
import flatpickr from "flatpickr";
import RangePlugin from "flatpickrRangePlugin";

function updateHelp(ctx) {
  const detailsEl = document.getElementById(
    "time-range-chooser-dropdown-menu-details",
  );

  const fromEl = ctx.element.querySelector("input[name='from']");
  const toEl = ctx.element.querySelector("input[name='to']");

  detailsEl.classList.remove("has-relative-time", "has-absolute-time");

  [fromEl, toEl].forEach((e) => {
    if (e.value.startsWith("now")) {
      detailsEl.classList.add("has-relative-time");
    } else {
      detailsEl.classList.add("has-absolute-time");
    }
  });
}

export default class extends Controller {
  connect() {
    const fromFpEl = document.getElementById("time-range-chooser-fp-from");
    const toFpEl = document.getElementById("time-range-chooser-fp-to");

    const fromEl = this.element.querySelector("input[name='from']");
    const toEl = this.element.querySelector("input[name='to']");

    this.flatpickr = flatpickr(fromFpEl, {
      mode: "range",
      plugins: [new RangePlugin({ input: toFpEl })],
      positionElement: this.element.querySelector("input[name=from]"),
      onOpen: (selectedDates, dateStr, instance) => {
        instance.clear();
      },
      onChange: (selectedDates, dateStr, instance) => {
        fromEl.value = "";
        toEl.value = "";

        // I can't find a way to get flatpickr to natively and cleanly deal in
        // UTC times. It seems to always/only use the browser's local time.
        // This isn't ideal, but as long as the user is only selecting dates
        // (not times), we can always treat the returned time-zoned Date as
        // though it were UTC, and just drop the time part.
        //
        // E.g., if a user in New York selects May 5, 2025, flatpickr will use:
        // Tue May 5 2025 00:00:00 GMT-0400. Even though that is technically
        // May 4th, if we ignore the time and time zone info, we do end up with
        // May 5, 2025, which is what we care about.

        if (selectedDates[0]) {
          fromEl.value = selectedDates[0].toISOString().split("T")[0];
        }

        if (selectedDates[1]) {
          toEl.value = selectedDates[1].toISOString().split("T")[0];
        }
      },
    });

    this.element.querySelectorAll(".calendar-toggle").forEach((el) => {
      el.addEventListener("click", (event) => {
        event.preventDefault();
        this.flatpickr.toggle();
      });
    });

    [fromEl, toEl].forEach((el) => {
      el.addEventListener("input", () => {
        updateHelp(this);
      });
    });

    updateHelp(this);
  }

  loadPreset(event) {
    const newFrom = event.target.getAttribute("data-dx-range-from");
    const newTo = event.target.getAttribute("data-dx-range-to");

    this.element.querySelector("input[name='from']").value = newFrom;
    this.element.querySelector("input[name='to']").value = newTo;

    updateHelp(this);
  }
}
