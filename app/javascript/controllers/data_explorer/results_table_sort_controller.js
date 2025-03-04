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

    const dimension = event.target.dataset.sortGroupDimension;
    const metric = event.target.dataset.sortMetric;
    const group2MemberDescriptor = event.target.getAttribute(
      "data-sort-group-2-member-descriptor",
    );

    if (event.target.dataset.sortConfig?.startsWith("0,")) {
      // this is already the active sort for this dimension

      if (event.target.dataset.sortConfig.endsWith(",ASC")) {
        event.target.dataset.sortConfig = "0,DESC";
      } else {
        event.target.dataset.sortConfig = "0,ASC";
      }
    } else {
      // Reset the sort property of all elements that belong to this group
      this.tableTarget
        .querySelectorAll(`*[data-sort-group-dimension="${dimension}"]`)
        .forEach((el) => {
          el.dataset.sortConfig = "";
        });

      // Set the config for the chosen element to make it the active sort
      event.target.dataset.sortConfig = "0,DESC";
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
          `td[data-sort-metric="${metric}"][data-sort-group-2-member-descriptor="${group2MemberDescriptor}"]`,
        );
        const tr2Cell = tr2.querySelector(
          `td[data-sort-metric="${metric}"][data-sort-group-2-member-descriptor="${group2MemberDescriptor}"]`,
        );

        if (!tr1Cell || !tr2Cell) {
          return -1;
        }

        return +tr2Cell.dataset.rawValue - +tr1Cell.dataset.rawValue;
      });

      const body = this.tableTarget.querySelector("tbody");

      if (event.target.dataset.sortConfig.endsWith(",ASC")) {
        sortedDataRows.reverse();
      }

      sortedDataRows.forEach((el) => el.remove());
      sortedDataRows.forEach((el) => body.append(el));
    }

    return;
    // event.preventDefault();

    // const button = event.target;

    // const header = button.closest("td");

    // const metric = header.getAttribute("data-highlight-metric");
    // const group = header.getAttribute("data-highlight-group-2");

    // // Collect all the data rows
    // const dataRows = [
    //   ...document.querySelectorAll("#results table tbody tr:not(.totals)"),
    // ];

    // // Sort the rows by the values found in cells that match the button's
    // // group and metric
    // const sortedDataRows = dataRows.sort((tr1, tr2) => {
    //   const tr1Cell = tr1.querySelector(
    //     `td[data-highlight-metric="${metric}"][data-highlight-group-2="${group}"]`,
    //   );
    //   const tr2Cell = tr2.querySelector(
    //     `td[data-highlight-metric="${metric}"][data-highlight-group-2="${group}"]`,
    //   );

    //   if (!tr1Cell || !tr2Cell) {
    //     return -1;
    //   }

    //   return +tr2Cell.dataset.rawValue - +tr1Cell.dataset.rawValue;
    // });

    // if (!button.dataset.direction) {
    //   button.dataset.direction = "desc";
    //   button.innerText = "↓";
    // } else if (button.dataset.direction === "desc") {
    //   button.dataset.direction = "asc";
    //   button.innerText = "↑";
    //   sortedDataRows.reverse();
    // } else if (button.dataset.direction === "asc") {
    //   button.innerText = "↓";
    //   button.dataset.direction = "desc";
    // }

    // const body = document.querySelector("#results table tbody");

    // sortedDataRows.forEach((el) => el.remove());
    // sortedDataRows.forEach((el) => body.append(el));
  }
}
