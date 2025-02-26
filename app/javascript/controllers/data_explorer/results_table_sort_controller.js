import { Controller } from "@hotwired/stimulus";

// TODO proof of concept
// TODO allow sorting on time series with 0 or 1 groups. Doesn't make sense with 2
// TODO Dimensional, allow sorting by group 1 totals
// TODO Allow sorting by group 1 (i.e., horizontally)
export default class extends Controller {
  // eslint-disable-next-line class-methods-use-this
  sort(event) {
    event.preventDefault();

    const button = event.target;

    const header = button.closest("td");

    const metric = header.getAttribute("data-highlight-metric");
    const group = header.getAttribute("data-highlight-group-2");

    // Collect all the data rows
    const dataRows = [
      ...document.querySelectorAll("#results table tbody tr:not(.totals)"),
    ];

    // Sort the rows by the values found in cells that match the button's
    // group and metric
    const sortedDataRows = dataRows.sort((tr1, tr2) => {
      const tr1Cell = tr1.querySelector(
        `td[data-highlight-metric="${metric}"][data-highlight-group-2="${group}"]`,
      );
      const tr2Cell = tr2.querySelector(
        `td[data-highlight-metric="${metric}"][data-highlight-group-2="${group}"]`,
      );

      if (!tr1Cell || !tr2Cell) {
        return -1;
      }

      return +tr2Cell.dataset.rawValue - +tr1Cell.dataset.rawValue;
    });

    if (!button.dataset.direction) {
      button.dataset.direction = "desc";
      button.innerText = "↓";
    } else if (button.dataset.direction === "desc") {
      button.dataset.direction = "asc";
      button.innerText = "↑";
      sortedDataRows.reverse();
    } else if (button.dataset.direction === "asc") {
      button.innerText = "↓";
      button.dataset.direction = "desc";
    }

    const body = document.querySelector("#results table tbody");

    sortedDataRows.forEach((el) => el.remove());
    sortedDataRows.forEach((el) => body.append(el));
  }
}
