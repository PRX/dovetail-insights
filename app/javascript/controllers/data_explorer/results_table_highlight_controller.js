import { Controller } from "@hotwired/stimulus";

// Takes a set of +arrays+, and returns a new set of arrays where each array
// represents a unique combination of values from the input arrays.
//
// E.g. generateCombinations([ [cat, dog], [apple, banana] ])
// => [
//      [cat, apple]
//      [cat, banana]
//      [dog, apple]
//      [dog, banana]
//    ]
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

/**
 * This controller is intended to set the background color of cells in a table
 * of composition results. A results table may include cells that are not
 * standard data values (like headers, aggregate values, etc.). This controller
 * will only highlight cells that are +cell+ targets of this controller.
 *
 * The full colorization process is meant to run each time any of the
 * highlighting options (scales, palettes, etc.) are changed.
 *
 * Based on the selected options, each cell is placed into a set with some
 * other cells. The intensity of the color of a given sell (the alpha value of
 * the applied background color) is determined by where that cell's value lands
 * in the range of values for that set. E.g., in a set with [0, 10, 50], the
 * cell containing 0 will be fully transparent, the cell containing 10 will be
 * slightly saturated, and the cell containing 50 will be fully saturated. If
 * in another group in the same table the values were [50, 100, 1000], the 50
 * cell would be transparent, and the other cells would be appropriately
 * saturated.
 *
 * The partition option determines how cells are placed into sets. The value of
 * the +partitionsSelectorTarget+ is a comma-separated list of values, where
 * each value is an HTML element attribute name. The controller will create
 * sets of cells where the values of the specified attributes are the match.
 *
 * For example, if the +partitionsSelectorTarget+ value is +data-dx-metric+,
 * and the table contains some cells with +data-dx-metric="downlodas"+ and
 * other cells with +data-dx-metric="impressions"+, the controller will create
 * two sets of cells, one for downloads and one for impressions.
 *
 * If instead the +partitionsSelectorTarget+ value is
 * "data-dx-metric,data-dx-group-1-member-descriptor", and the table also
 * contains cells for both Song Exploder and Ear Hustle, each unique
 * combination of metrics and group 1 members will be used to create sets, thus
 * 4 total sets will be made.
 */
export default class extends Controller {
  static targets = [
    "table",
    "chooser",
    "scaleSelector",
    "paletteSelector",
    "partitionsSelector",
    "cell",
  ];

  highlightValues(cellPartitions) {
    const paletteOpt = this.paletteSelectorTarget.value;

    let i = 0;
    // cellPartitions will be an array of arrays. Each array is a set of cells
    cellPartitions.forEach((cells) => {
      let max = 0;
      let min = 99999999;

      // Look through all cells in this partition and find the min and max
      cells.forEach((cell) => {
        const val = cell.dataset.dxDataPoint
          ? +cell.dataset.dxDataPoint
          : undefined;

        if (val) {
          if (val > max) {
            max = val;
          }

          if (val < min) {
            min = val;
          }
        }
      });

      let h;

      if (paletteOpt === "rainbow") {
        // Give a color to this partition. The goal is to have neighboring cells
        // in the table have sufficiently distinct colors while not using so
        // many different colors that the table looks ridiculous.
        const numColors = 10; // Any even number
        const maxHue = 295;
        const hueStep = maxHue / (numColors - 1);

        // Map the input to range 0-9
        const cycle = i % numColors;

        // 0 in the first half of the cycle, 1 in the second half
        const adj = Math.round((i % numColors) / numColors);

        // Rather than [0,1,2,3,4,5,6,7,8,9,0,1,2,3,4,5]
        // we want     [0,2,4,6,8,1,3,5,7,9,0,2,4,6,8,1]
        // to keep a litte more color distance between adjacent rows/columns
        const factor = ((cycle * 2) % numColors) + adj;

        h = hueStep * factor;
      } else if (paletteOpt === "monochrome") {
        h = 30;
      }

      // Apply the color for each cell, comparing the cell's value to the
      // min/max for the partition it belongs to, based on the selected scale.
      cells.forEach((cell) => {
        const val = cell.dataset.dxDataPoint
          ? +cell.dataset.dxDataPoint
          : undefined;

        if (val) {
          let relativeValue;

          if (this.scaleSelectorTarget.value === "log") {
            relativeValue =
              (Math.log(val) - Math.log(min)) / (Math.log(max) - Math.log(min));
          } else if (this.scaleSelectorTarget.value === "linear") {
            relativeValue = (val - min) / (max - min);
          }

          cell.style.background = `oklch(67% 0.25 ${h} / ${relativeValue})`;
        }
      });

      i += 1;
    });
  }

  highlightDeltas(cellPartitions) {
    const paletteOpt = this.paletteSelectorTarget.value;

    cellPartitions.forEach((cells) => {
      let previousValue;

      cells.forEach((cell) => {
        const val = +cell.dataset.dxDataPoint;

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
      // Get the comma separated options from the form. This will be a string
      // like "data-dx-metric" or
      // "data-dx-metric,data-dx-group-1-member-descriptor"
      const partitionsOpt = this.partitionsSelectorTarget.value;

      // The +deltas+ options is a special case; we detect if it's present and
      // then drop it from options.
      const showDeltas = partitionsOpt.startsWith("delta,");
      const partitionAttrs = partitionsOpt.replace("delta,", "").split(",");

      const cells = this.cellTargets;

      // cellPartitions will be an array or arrays.
      const cellPartitions = [];

      if (!partitionsOpt) {
        // Put all cells in a single partition
        cellPartitions.push(cells);
      } else {
        // For each attribute listed in the partition option, look up all the
        // unique values for that attribute present in the table. This will
        // result in an array of arrays.
        const partitionAttrsUniqs = partitionAttrs.map(
          (a) => new Set([...cells].map((c) => c.getAttribute(a))),
        );

        // Collect all unique combinations of the attribute values. Each
        // combination is a desired partition.
        generateCombinations(partitionAttrsUniqs).forEach((combo) => {
          // Create a CSS selector using the values in this combination for the
          // related attributes.
          //
          // E.g. if the combo is ["downloads", "song exploder"], and the
          // partitionAttrs are ["data-dx-metric", "data-dx-group-1-member-descriptor"],
          // the selector will be:
          // td[data-dx-metric="downloads"][data-dx-group-1-member-descriptor="song exploder"]
          const selector = `td${combo.map((v, idx) => `[${partitionAttrs[idx]}="${v}"]`).join("")}`;
          // Find all the cells that match the selector and belong to this
          // partition
          const cellsForPartition = this.tableTarget.querySelectorAll(selector);

          // Reset all background colors before highlighting.
          cellsForPartition.forEach((cell) => {
            cell.style.background = `hsla(0 0% 0% / 0)`;
          });

          cellPartitions.push(cellsForPartition);
        });
      }

      if (showDeltas) {
        this.highlightDeltas(cellPartitions);
      } else {
        this.highlightValues(cellPartitions);
      }
    }
  }

  connect() {
    this.highlight();
  }
}
