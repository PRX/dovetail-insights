import { Controller } from "@hotwired/stimulus";

// TODO For time series comparisons, there should be an option to highlight
// based on the change over time within a group.
export default class extends Controller {
  static targets = ["table"];

  connect() {
    const tbl = this.tableTarget;

    const allCells = tbl.querySelectorAll("td[data-raw-value]");

    const uniqHighlightGroups = new Set(
      Array(...allCells).map((c) => c.dataset.highlightGroup),
    );

    let i = 0;
    for (const highlightGroup of uniqHighlightGroups) {
      const cells = tbl.querySelectorAll(
        `td[data-highlight-group='${highlightGroup}']`,
      );

      let max = 0;
      let min = 99999999;

      for (const cell of cells) {
        const val = +cell.dataset.rawValue;

        if (val > max) {
          max = val;
        }

        if (val !== 0 && val < min) {
          min = val;
        }
      }

      const hue = 298 - i * 60;

      for (const cell of cells) {
        const val = +cell.dataset.rawValue;
        const scale =
          (Math.log(val) - Math.log(min)) / (Math.log(max) - Math.log(min));
        cell.style.background = `hsla(${hue} 100% 68% / ${scale})`;
      }

      i += 1;
    }
  }
}
