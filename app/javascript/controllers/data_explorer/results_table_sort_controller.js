// @ts-nocheck
import { Controller } from "@hotwired/stimulus";

// TODO proof of concept
// TODO allow sorting on time series with 0 or 1 groups. Doesn't make sense with 2
export default class extends Controller {
  static targets = ["table", "row", "rowSortOpt"];

  sort_rows() {
    const sortedDataRows = this.rowTargets.sort((rowA, rowB) => {
      // eslint-disable-next-line no-restricted-syntax
      for (const rowSortOpt of this.rowSortOptTargets) {
        const sortDirection = rowSortOpt.querySelector(".sort-direction").value;
        // The value of the sort-by <select> is going to be a CSS selector to
        // find a particular cell in each row, which will be used for the
        // comparison.
        const sortBy = rowSortOpt.querySelector(".sort-by").value;

        if (sortBy && sortBy !== "no-sort") {
          // Get the relevant cells. There are four types of cell that may be
          // found:
          //  - Data Point cell, with [data-dx-data-point] which is used for
          //    the comparison value
          //  - A meta field cell, with [data-dx-group-1-meta-<some field name>]
          //    whose cell text is used for the comparison
          //  - A total, TODO
          //  - The row header cell, wih [dx-group-<group_num>-member-sort-values],
          //    where the value of that attribute is a LIST of values that are
          //    compared in order
          const rowACell = rowA.querySelector(`*${sortBy}`);
          const rowBCell = rowB.querySelector(`*${sortBy}`);

          if (rowACell && rowBCell) {
            let result;

            if (sortBy === "[data-dx-group-1-default-sort-index]") {
              const rowAValue = rowACell.getAttribute(
                "data-dx-group-1-default-sort-index",
              );
              const rowBValue = rowBCell.getAttribute(
                "data-dx-group-1-default-sort-index",
              );
              result = +rowAValue - +rowBValue;
            } else if (rowACell.dataset.dxDataPoint) {
              const rowAValue = rowACell.dataset.dxDataPoint;
              const rowBValue = rowBCell.dataset.dxDataPoint;
              result = +rowAValue - +rowBValue;
            } else if (rowACell.dataset.dxAggPointSum) {
              const rowAValue = rowACell.dataset.dxAggPointSum;
              const rowBValue = rowBCell.dataset.dxAggPointSum;
              result = +rowAValue - +rowBValue;
            } else {
              const rowAValue = rowACell.innerText;
              const rowBValue = rowBCell.innerText;
              result = rowAValue.localeCompare(rowBValue);
            }

            if (sortDirection === "desc") result *= -1;

            if (result !== 0) return result;
          }
        }
      }
      return 0;
    });

    const body = this.tableTarget.querySelector("tbody");

    sortedDataRows.forEach((el) => el.remove());
    sortedDataRows.forEach((el) => body.append(el));
  }

  sort_cols() {
    const sortDirection = document.querySelector(".col-sort-direction").value;
    const sortBy = document.querySelector(".col-sort-by").value;

    let sortRow;

    if (sortBy === "default") {
      sortRow = this.tableTarget.querySelector("thead tr:first-of-type");
    } else if (sortBy === "total") {
      sortRow = this.tableTarget.querySelector("tbody tr:first-of-type");
    } else if (sortBy === "first-row") {
      sortRow = this.tableTarget.querySelector(
        "tbody tr:has(td[data-dx-data-point])",
      );
    }

    const sortRowCellsInCurrentOrder = [...sortRow.querySelectorAll("th,td")];

    // This will get sorted in place
    const sortedSortRowCells = [...sortRow.querySelectorAll("th,td")];

    if (sortBy === "default") {
      sortedSortRowCells.sort((cellA, cellB) => {
        if (!cellA.getAttribute("data-dx-group-2-default-sort-index")) {
          return -1;
        }

        const cellAValue = cellA.getAttribute(
          "data-dx-group-2-default-sort-index",
        );
        const cellBValue = cellB.getAttribute(
          "data-dx-group-2-default-sort-index",
        );

        return (
          (+cellAValue - +cellBValue) * (sortDirection === "desc" ? -1 : 1)
        );
      });
    } else if (sortBy === "total") {
      sortedSortRowCells.sort((cellA, cellB) => {
        if (!cellA.dataset.dxAggPointSum) {
          return -1;
        }

        const cellAValue = cellA.dataset.dxAggPointSum;
        const cellBValue = cellB.dataset.dxAggPointSum;

        return (
          (+cellAValue - +cellBValue) * (sortDirection === "desc" ? -1 : 1)
        );
      });
    } else if (sortBy === "first-row") {
      sortedSortRowCells.sort((cellA, cellB) => {
        if (!cellA.dataset.dxDataPoint) {
          return -1;
        }

        const cellAValue = cellA.dataset.dxDataPoint;
        const cellBValue = cellB.dataset.dxDataPoint;

        return (
          (+cellAValue - +cellBValue) * (sortDirection === "desc" ? -1 : 1)
        );
      });
    }

    const sortMap = sortedSortRowCells.map((cell) => {
      return sortRowCellsInCurrentOrder.indexOf(cell);
    });

    const rows = [...this.tableTarget.querySelectorAll("tr")];
    rows.forEach((row) => {
      const cells = [...row.querySelectorAll("th,td")];
      cells.forEach((cell) => cell.remove());

      sortMap.forEach((mapping) => {
        const cell = cells[mapping];
        row.append(cell);
      });
    });

    // ["thead", "tbody"].forEach((sectionTag) => {
    //   const section = this.tableTarget.querySelector(sectionTag);
    //   const rows = [...section.querySelectorAll("tr")];

    //   rows.forEach((row) => {
    //     const cells = [...row.querySelectorAll("th,td")];

    //     cells.forEach((cell) => cell.remove());

    //     sortMap.forEach((mapping) => {
    //       const cell = cells[mapping];
    //       row.append(cell);
    //     });
    //   });
    // });
  }

  sort() {
    this.sort_rows();
    this.sort_cols();
  }
}
