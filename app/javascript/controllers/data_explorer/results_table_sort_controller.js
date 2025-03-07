import { Controller } from "@hotwired/stimulus";

// TODO proof of concept
// TODO allow sorting on time series with 0 or 1 groups. Doesn't make sense with 2
// TODO Dimensional, allow sorting by group 1 totals
// TODO Allow sorting by group 1 (i.e., horizontally)
export default class extends Controller {
  static targets = ["table", "row"];

  // eslint-disable-next-line class-methods-use-this
  sort(event) {
    // TODO support multiple metrics and comparisons

    const metric = event.target.dataset.dxMetric;

    let selector;
    let dimensionName;
    let memberDescriptor;
    if (event.target.getAttribute("data-dx-group-1-dimension-name")) {
      selector = "data-dx-group-1-dimension-name";
      dimensionName = event.target.getAttribute(
        "data-dx-group-1-dimension-name",
      );
      memberDescriptor = event.target.getAttribute(
        "data-dx-group-1-member-descriptor",
      );
    } else if (event.target.getAttribute("data-dx-group-2-dimension-name")) {
      selector = "data-dx-group-2-dimension-name";
      dimensionName = event.target.getAttribute(
        "data-dx-group-2-dimension-name",
      );
      memberDescriptor = event.target.getAttribute(
        "data-dx-group-2-member-descriptor",
      );
    }

    if (event.target.dataset.dxSortConfig?.startsWith("0,")) {
      // this is already the active sort for this dimension

      if (event.target.dataset.dxSortConfig.endsWith(",ASC")) {
        event.target.dataset.dxSortConfig = "0,DESC";
      } else {
        event.target.dataset.dxSortConfig = "0,ASC";
      }
    } else {
      // Reset the sort property of all elements that belong to this group
      this.tableTarget
        .querySelectorAll(`*[${selector}="${dimensionName}"]`)
        .forEach((el) => {
          el.dataset.dxSortConfig = "";
        });

      // Set the config for the chosen element to make it the active sort
      event.target.dataset.dxSortConfig = "0,DESC";
    }

    const containingRow = event.target.closest("tr");
    const cellIdx = Array.from(containingRow.cells).indexOf(event.target);

    if (cellIdx === 0) {
      // event was on a row header and we should sort the columns
    } else {
      // event was on a column header and we should sort the row

      // Sort the rows by the values found in cells that match the target's
      // group and metric
      const sortedDataRows = this.rowTargets.sort((tr1, tr2) => {
        const tr1Cell = tr1.querySelector(
          `td[data-dx-metric="${metric}"][data-dx-group-2-member-descriptor="${memberDescriptor}"]`,
        );
        const tr2Cell = tr2.querySelector(
          `td[data-dx-metric="${metric}"][data-dx-group-2-member-descriptor="${memberDescriptor}"]`,
        );

        if (!tr1Cell || !tr2Cell) {
          return -1;
        }

        return +tr2Cell.dataset.rawValue - +tr1Cell.dataset.rawValue;
      });

      const body = this.tableTarget.querySelector("tbody");

      if (event.target.dataset.dxSortConfig.endsWith(",ASC")) {
        sortedDataRows.reverse();
      }

      sortedDataRows.forEach((el) => el.remove());
      sortedDataRows.forEach((el) => body.append(el));
    }
  }
}
