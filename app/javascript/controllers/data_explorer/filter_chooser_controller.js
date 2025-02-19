import { Controller } from "@hotwired/stimulus";

const hours = Array.from({ length: 24 }, (v, idx) => idx);
const dow = [
  [0, "Sunday"],
  [1, "Monday"],
  [2, "Tuesday"],
  [3, "Wednesday"],
  [4, "Thursday"],
  [5, "Friday"],
  [6, "Saturday"],
];
const days = Array.from({ length: 31 }, (v, idx) => idx);
const weeks = Array.from({ length: 52 }, (v, idx) => idx);
const months = [
  [1, "January"],
  [2, "February"],
  [3, "March"],
  [4, "April"],
  [5, "May"],
  [6, "June"],
  [7, "July"],
  [8, "August"],
  [9, "September"],
  [10, "October"],
  [11, "November"],
  [12, "December"],
];
// TODO Always include up to the current year
const years = Array.from({ length: 16 }, (v, idx) => 2010 + idx);

export default class extends Controller {
  static targets = ["extractBy", "values"];

  connect() {
    this.setExtract();
  }

  setExtract() {
    // TODO Right now this is responsible for all rendering of this element.
    // At least the initial loading should be moved into the Rails view.
    const extractBy = this.extractByTarget.value;

    this.valuesTarget.innerHTML = "";

    if (extractBy === "hour") {
      const htmlString = hours.map((h) => `<option value="${h}">${h}</option>`);
      this.valuesTarget.innerHTML = htmlString;
    } else if (extractBy === "day_of_week") {
      const htmlString = dow.map(
        (v) => `<option value="${v[0]}">${v[1]}</option>`,
      );
      this.valuesTarget.innerHTML = htmlString;
    } else if (extractBy === "day") {
      const htmlString = days.map((d) => `<option value="${d}">${d}</option>`);
      this.valuesTarget.innerHTML = htmlString;
    } else if (extractBy === "week") {
      const htmlString = weeks.map((w) => `<option value="${w}">${w}</option>`);
      this.valuesTarget.innerHTML = htmlString;
    } else if (extractBy === "month") {
      const htmlString = months.map(
        (v) => `<option value="${v[0]}">${v[1]}</option>`,
      );
      this.valuesTarget.innerHTML = htmlString;
    } else if (extractBy === "year") {
      const htmlString = years.map((y) => `<option value="${y}">${y}</option>`);
      this.valuesTarget.innerHTML = htmlString;
    }

    // TODO Hack until rendering is moved to Rails view, to set chosen values
    // from the URL as selected
    const dimKey = this.element.closest("li > fieldset").dataset.dimensionKey;
    const val = new URL(window.location.toString()).searchParams.get(
      `filter.${dimKey}.values`,
    );
    if (val) {
      const vals = val.split(",").map((v) => v.trim());

      const optionEls = this.valuesTarget.querySelectorAll("option");
      optionEls.forEach((optionEl) => {
        if (vals.includes(optionEl.value)) {
          optionEl.selected = true;
        }
      });
    }
  }
}
