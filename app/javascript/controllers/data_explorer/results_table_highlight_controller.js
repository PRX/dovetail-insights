import { Controller } from "@hotwired/stimulus";

function generateCombinations(arrays, depth = 0, path = [], result = []) {
  if (depth === arrays.length) {
    result.push([...path]);
    return;
  }

  arrays[depth].forEach((uniq) => {
    generateCombinations(arrays, depth + 1, [...path, uniq], result);
  });

  // eslint-disable-next-line consistent-return
  return result;
}

// TODO Proof of concept
// TODO For time series comparisons, there should be an option to highlight
// based on the change over time within a group.
export default class extends Controller {
  static targets = [
    "table",
    "chooser",
    "scale",
    "palette",
    "divisions",
    "cell",
  ];

  highlightValues(spectrumCellSets) {
    const paletteOpt = this.paletteTarget.value;

    let i = 0;
    spectrumCellSets.forEach((cellSet) => {
      let max = 0;
      let min = 99999999;

      cellSet.forEach((cell) => {
        const val = +cell.dataset.rawValue;

        if (val > max) {
          max = val;
        }

        if (val !== 0 && val < min) {
          min = val;
        }
      });

      let hue;

      if (paletteOpt === "rainbow") {
        hue = 298 - i * 51;
      } else if (paletteOpt === "monochrome") {
        hue = 298 - 0 * 51;
      }

      cellSet.forEach((cell) => {
        const val = +cell.dataset.rawValue;

        let scale;

        if (this.scaleTarget.value === "log") {
          scale =
            (Math.log(val) - Math.log(min)) / (Math.log(max) - Math.log(min));
        } else if (this.scaleTarget.value === "linear") {
          scale = (val - min) / (max - min);
        }

        cell.style.background = `hsla(${hue} 100% 68% / ${scale})`;
      });

      i += 1;
    });
  }

  highlightDeltas(spectrumCellSets) {
    const paletteOpt = this.paletteTarget.value;

    spectrumCellSets.forEach((cellSet) => {
      let previousValue;

      cellSet.forEach((cell) => {
        const val = +cell.dataset.rawValue;

        if (previousValue) {
          const percentDelta = (val - previousValue) / previousValue;

          let hue = percentDelta > 0 ? 132 : 5;
          const opacity = Math.min(1, Math.abs(percentDelta / 0.3));

          if (paletteOpt === "monochrome") {
            hue = 30;
          }

          cell.style.background = `hsla(${hue} 100% 34% / ${opacity})`;
        } else {
          cell.style.background = `hsla(0 100% 34% / 0)`;
        }

        previousValue = val;
      });
    });
  }

  highlight() {
    if (this.hasTableTarget) {
      const spectrumsOpt = this.divisionsTarget.value;

      const showDeltas = spectrumsOpt.startsWith("delta,");
      const aspects = spectrumsOpt.replace("delta,", "").split(",");

      const cells = this.cellTargets;
      const cellDivisions = [];

      const uniques = {
        "data-dx-metric": new Set([...cells].map((c) => c.dataset.dxMetric)),
        "data-dx-group-1-member-descriptor": new Set(
          [...cells].map((c) =>
            c.getAttribute("data-dx-group-1-member-descriptor"),
          ),
        ),
        "data-dx-group-2-member-descriptor": new Set(
          [...cells].map((c) =>
            c.getAttribute("data-dx-group-2-member-descriptor"),
          ),
        ),
        "data-dx-interval-descriptor": new Set(
          [...cells].map((c) => c.getAttribute("data-dx-interval-descriptor")),
        ),
      };

      if (!spectrumsOpt) {
        // Put all cells in a single division
        cellDivisions.push(cells);
      } else {
        const aspectUniqs = aspects.map((a) => uniques[a]);

        generateCombinations(aspectUniqs).forEach((combo) => {
          const selector = `td${combo.map((v, idx) => `[${aspects[idx]}="${v}"]`).join("")}`;
          const cellsForDivision = this.tableTarget.querySelectorAll(selector);

          cellsForDivision.forEach((cell) => {
            cell.style.background = `hsla(0 0% 0% / 0)`;
          });

          cellDivisions.push(cellsForDivision);
        });
      }

      if (showDeltas) {
        this.highlightDeltas(cellDivisions);
      } else {
        this.highlightValues(cellDivisions);
      }
    }
  }

  connect() {
    this.highlight();
  }
}
