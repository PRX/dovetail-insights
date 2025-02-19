import { Controller } from "@hotwired/stimulus";

// TODO Proof of concept
// TODO For time series comparisons, there should be an option to highlight
// based on the change over time within a group.
export default class extends Controller {
  static targets = ["table", "chooser", "scale", "palette", "spectrums"];

  highlightValues(spectrumCellSets) {
    const paletteOpt = this.paletteTarget.value;

    let i = 0;
    for (const cellSet of spectrumCellSets) {
      let max = 0;
      let min = 99999999;

      for (const cell of cellSet) {
        const val = +cell.dataset.rawValue;

        if (val > max) {
          max = val;
        }

        if (val !== 0 && val < min) {
          min = val;
        }
      }

      let hue;

      if (paletteOpt === "rainbow") {
        hue = 298 - i * 51;
      } else if (paletteOpt === "monochrome") {
        hue = 298 - 0 * 51;
      }

      for (const cell of cellSet) {
        const val = +cell.dataset.rawValue;

        let scale;

        if (this.scaleTarget.value === "log") {
          scale =
            (Math.log(val) - Math.log(min)) / (Math.log(max) - Math.log(min));
        } else if (this.scaleTarget.value === "linear") {
          scale = (val - min) / (max - min);
        }

        cell.style.background = `hsla(${hue} 100% 68% / ${scale})`;
      }

      i += 1;
    }
  }

  highlightDeltas(spectrumCellSets) {
    const paletteOpt = this.paletteTarget.value;

    for (const cellSet of spectrumCellSets) {
      let previousValue = undefined;

      for (const cell of cellSet) {
        const val = +cell.dataset.rawValue;

        if (previousValue) {
          const percentDelta = (val - previousValue) / previousValue;

          const hue = percentDelta > 0 ? 132 : 5;
          const opacity = Math.min(1, Math.abs(percentDelta / 0.3));

          cell.style.background = `hsla(${hue} 100% 34% / ${opacity})`;
        } else {
          cell.style.background = `hsla(0 100% 34% / 0)`;
        }

        previousValue = val;
      }
    }
  }

  highlight() {
    if (this.tableTarget) {
      const resultsTable = this.tableTarget;

      const spectrumsOpt = this.spectrumsTarget.value;

      const allCells = resultsTable.querySelectorAll("td[data-raw-value]");
      const spectrumCellSets = [];

      if (spectrumsOpt === "all_values") {
        // Put all cells in a single set
        spectrumCellSets.push(allCells);
      } else if (spectrumsOpt === "per_metric") {
        const uniqMetrics = new Set(
          Array(...allCells).map((c) => c.dataset.highlightMetric),
        );
        for (const metric of uniqMetrics) {
          spectrumCellSets.push(
            resultsTable.querySelectorAll(
              `td[data-highlight-metric="${metric}"]`,
            ),
          );
        }
      } else if (spectrumsOpt === "per_metric_group_1") {
        const uniqMetrics = new Set(
          Array(...allCells).map((c) => c.dataset.highlightMetric),
        );

        const uniqGroup1Members = new Set(
          Array(...allCells).map((c) =>
            c.getAttribute("data-highlight-group-1"),
          ),
        );

        for (const metric of uniqMetrics) {
          for (const member of uniqGroup1Members) {
            spectrumCellSets.push(
              resultsTable.querySelectorAll(
                `td[data-highlight-metric="${metric}"][data-highlight-group-1="${member}"]`,
              ),
            );
          }
        }
      } else if (spectrumsOpt === "per_metric_group_2") {
        const uniqMetrics = new Set(
          Array(...allCells).map((c) => c.dataset.highlightMetric),
        );

        const uniqGroup2Members = new Set(
          Array(...allCells).map((c) =>
            c.getAttribute("data-highlight-group-2"),
          ),
        );

        for (const metric of uniqMetrics) {
          for (const member of uniqGroup2Members) {
            spectrumCellSets.push(
              resultsTable.querySelectorAll(
                `td[data-highlight-metric="${metric}"][data-highlight-group-2="${member}"]`,
              ),
            );
          }
        }
      } else if (spectrumsOpt === "per_metric_granularity") {
        const uniqMetrics = new Set(
          Array(...allCells).map((c) => c.dataset.highlightMetric),
        );

        const uniqGranularityMembers = new Set(
          Array(...allCells).map((c) =>
            c.getAttribute("data-highlight-granularity"),
          ),
        );

        for (const metric of uniqMetrics) {
          for (const member of uniqGranularityMembers) {
            spectrumCellSets.push(
              resultsTable.querySelectorAll(
                `td[data-highlight-metric="${metric}"][data-highlight-granularity="${member}"]`,
              ),
            );
          }
        }
      } else if (spectrumsOpt === "per_metric_group_1_delta") {
        const uniqMetrics = new Set(
          Array(...allCells).map((c) => c.dataset.highlightMetric),
        );

        const uniqGroup1Members = new Set(
          Array(...allCells).map((c) =>
            c.getAttribute("data-highlight-group-1"),
          ),
        );

        for (const metric of uniqMetrics) {
          for (const member of uniqGroup1Members) {
            spectrumCellSets.push(
              resultsTable.querySelectorAll(
                `td[data-highlight-metric="${metric}"][data-highlight-group-1="${member}"]`,
              ),
            );
          }
        }
      }

      if (spectrumsOpt === "per_metric_group_1_delta") {
        this.highlightDeltas(spectrumCellSets);
      } else {
        this.highlightValues(spectrumCellSets);
      }
    }
  }

  connect() {
    this.highlight();
  }
}
