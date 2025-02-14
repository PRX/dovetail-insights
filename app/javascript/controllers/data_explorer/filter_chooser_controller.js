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
const years = Array.from({ length: 11 }, (v, idx) => 2015 + idx);

export default class extends Controller {
  static targets = ["extractBy", "values"];

  setExtract() {
    const extractBy = this.extractByTarget.value;

    this.valuesTarget.innerHTML = "";

    if (extractBy === "hour") {
      const htmlString = hours.map((h) => `<option>${h}</option>`);
      this.valuesTarget.innerHTML = htmlString;
    } else if (extractBy === "day of week") {
      const htmlString = dow.map(
        (v) => `<option value="${v[0]}">${v[1]}</option>`,
      );
      this.valuesTarget.innerHTML = htmlString;
    } else if (extractBy === "day") {
      const htmlString = days.map((d) => `<option>${d}</option>`);
      this.valuesTarget.innerHTML = htmlString;
    } else if (extractBy === "week") {
      const htmlString = weeks.map((w) => `<option>${w}</option>`);
      this.valuesTarget.innerHTML = htmlString;
    } else if (extractBy === "month") {
      const htmlString = months.map(
        (v) => `<option value="${v[0]}">${v[1]}</option>`,
      );
      this.valuesTarget.innerHTML = htmlString;
    } else if (extractBy === "year") {
      const htmlString = years.map((y) => `<option>${y}</option>`);
      this.valuesTarget.innerHTML = htmlString;
    }
  }
}
