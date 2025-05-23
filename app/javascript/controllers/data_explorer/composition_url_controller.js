import { Controller } from "@hotwired/stimulus";

// function mergeSearchParams(...paramsList) {
//   const mergedParams = new URLSearchParams();

//   paramsList.forEach((params) => {
//     params.forEach((value, key) => {
//       mergedParams.append(key, value);
//     });
//   });

//   return mergedParams;
// }

// URLSearchParams.toString() encodes some characters that don't need to be,
// and these are meaningful characters in our URLs, which are beneficial to
// keep as literals. For example, if we did `params.set` for a value that
// included commas, the commas would be encoded, but we'd prefer to have them
// as literal commas in the final URL.
//
// So we force some of those encoded characters back to the original
// characters.
//
function cleanStringForSearchParamsString(paramsString) {
  const cleanedString = paramsString
    .replaceAll("%2F", "/")
    .replaceAll("%2C", ",")
    .replaceAll("%3A", ":");
  return cleanedString;
}

// function cleanStringForSearchParams(searchParams) {
//   const paramsString = searchParams.toString();

//   return cleanStringForSearchParamsString(paramsString);
// }

function lensParamsString() {
  const lensParams = new URLSearchParams();

  lensParams.set(
    "lens",
    new URLSearchParams(window.location.search).get("lens"),
  );

  return lensParams.toString();
}

function normalizeDateLikeString(str) {
  const dateMatch = str.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);

  if (dateMatch) {
    return `${dateMatch[1]}-${dateMatch[2].padStart(2, "0")}-${dateMatch[3].padStart(2, "0")}T00:00:00Z`;
  }

  const timeMatch = str.match(
    /^(\d{4})-(\d{1,2})-(\d{1,2})T(\d{1,2}):(\d{2}):(\d{2})Z$/,
  );
  if (timeMatch) {
    return `${timeMatch[1]}-${timeMatch[2].padStart(2, "0")}-${timeMatch[3].padStart(2, "0")}T${timeMatch[4].padStart(2, "0")}:${timeMatch[5]}:${timeMatch[6]}Z`;
  }

  return undefined;
}

export default class extends Controller {
  static targets = [
    "lens",
    "from",
    "to",
    "filterChooser",
    "metric",
    "groupChooser",
    "granularity",
    "granularityWindow",
    "cumeWindow",
    "compare",
  ];

  rangeParamsString() {
    const rangeParams = new URLSearchParams();

    let from = this.fromTarget?.value.trim();
    if (from) {
      // If the value looks like a date or date/time, do some basic
      // normalization, to expand, e.g., 2024-1-1 to 2024-01-01T00:00:00Z
      if (from.match(/^\d{4}-/)) {
        from = normalizeDateLikeString(from);
      }

      rangeParams.set("from", from);
    }

    const rawTo = this.toTarget?.value.trim();
    let to = this.toTarget?.value.trim();
    if (to) {
      if (to.match(/^\d{4}-/)) {
        to = normalizeDateLikeString(to);

        // If the given value is a **date only** with no time part (e.g.,
        // 2025-1-1 or 2025-01-01), for the range end we want the user to be
        // able to treat these as _inclusive_, which is different than nearly
        // every other part of the app, which treats range end as exclusive.
        // So if we see raw input that is a date only, we need to add a day.
        // Example:
        // Raw => 2025-1-9
        // Normalized => 2025-01-09T00:00:00Z
        // Adjusted => 2025-01-10T00:00:00Z
        if (rawTo.match(/^\d{4}-\d{1,2}-\d{1,2}$/)) {
          const parsed = new Date(Date.parse(to));
          // In-place update, move forward 1 day
          parsed.setUTCDate(parsed.getUTCDate() + 1);
          // Drop the fractional seconds
          to = parsed.toISOString().replace(".000Z", "Z");
        }
      }
      rangeParams.set("to", to);
    }

    // We do this with plus signs, since plus signs can appear in relative time
    // expresssions. But note that converting those back to literal plus signs in
    // the URL means that they will be interpreted as **spaces**, since a plus
    // sign in a URL query always represents an encoded space. We still do this
    // to maintain readability of the URL, and handle spaces as a special case in
    // the from and to query parameters on the server side. See
    // BaseLensComposition#from= for more info.
    return rangeParams.toString().replaceAll("%2B", "+");
  }

  filtersParamsString() {
    const filtersParams = new URLSearchParams();

    // For each filter chooser
    this.filterChooserTargets.forEach((filterChooser) => {
      // Ignore if the chooser isn't visible
      if (!filterChooser.classList.contains("filter-added")) {
        return;
      }

      // Get the dimension key for the associated dimension
      const { dimensionKey } = filterChooser.dataset;

      // The operator (include/exclude) is its own parameter; set the param if
      // an the user has made a selection.
      const operatorEl = filterChooser.querySelector(
        `*[name="filter.${dimensionKey}"]`,
      );
      if (operatorEl?.value) {
        filtersParams.set(operatorEl.name, operatorEl.value);
      }

      // Filters for dimensions with a Token type provide some sort of
      // multiselect UI. Get all the IDs or keys for the options the user
      // selected, and create a comma delimited list with them.
      if (filterChooser.dataset.dimensionType === "Token") {
        const valuesSelect = filterChooser.querySelector("select.token-select");
        if (valuesSelect?.selectedOptions.length) {
          const { selectedOptions } = valuesSelect;
          filtersParams.set(
            valuesSelect.name,
            Array.from(selectedOptions)
              .map((o) => o.value)
              .join(","),
          );
        } else {
          const valuesTextField = filterChooser.querySelector("input.value");
          if (valuesTextField?.value.length) {
            filtersParams.set(
              valuesTextField.name,
              valuesTextField.value
                .split(",")
                .map((v) => v.trim())
                .join(","),
            );
          }
        }

        const nullsCheckbox = filterChooser.querySelector(
          `*[name="filter.${dimensionKey}.nulls"]:checked`,
        );
        if (nullsCheckbox) {
          filtersParams.set(nullsCheckbox.name, "follow");
        }
      }

      // Filters for dimensions with a Duration type take two values, a "gte"
      // and a "lt". Each gets its own URL parameter when provided by the user.
      if (filterChooser.dataset.dimensionType === "Duration") {
        // By default, don't assume any shorthand unit (i.e., seconds)
        let unit = "";

        // If the unit <select> is present, use its value as the unit
        const unitEl = filterChooser.querySelector(
          `*[name="filter.${dimensionKey}.unit"]`,
        );
        if (unitEl?.value) {
          unit = unitEl.value;
        }

        const gteEl = filterChooser.querySelector(
          `*[name="filter.${dimensionKey}.gte"]`,
        );
        if (gteEl?.value) {
          // If the value is a shorthand value, always use that, otherwise
          // inherit the unit from the <select>
          if (gteEl.value.match(/^[0-9]+[YWDhm]$/)) {
            filtersParams.set(gteEl.name, gteEl.value);
          } else {
            const valueWithUnit = `${gteEl.value}${unit}`;
            filtersParams.set(gteEl.name, valueWithUnit);
          }
        }

        const ltEl = filterChooser.querySelector(
          `*[name="filter.${dimensionKey}.lt"]`,
        );
        if (ltEl?.value) {
          // If the value is a shorthand value, always use that, otherwise
          // inherit the unit from the <select>
          if (ltEl.value.match(/^[0-9]+[YWDhm]$/)) {
            filtersParams.set(ltEl.name, ltEl.value);
          } else {
            const valueWithUnit = `${ltEl.value}${unit}`;
            filtersParams.set(ltEl.name, valueWithUnit);
          }
        }
      }

      // Filters for dimensions with a Timestamp type operate in one of two
      // modes:
      //
      // Range: a "from" and "to" value are provided, and each is set to its
      // own URL parameter
      //
      // Extract: The user chooses a date part to extract on (hour, month, etc),
      // and a set of values from all possible options for that date part. For
      // example, if the user selects to extract on "month", they may choose
      // "January" and "February" from a list of all months.
      if (filterChooser.dataset.dimensionType === "Timestamp") {
        const modeEl = filterChooser.querySelector(
          `*[name="filter.${dimensionKey}.timestamp-mode"]`,
        );

        // In Range mode, set a URL for each of the "from" and "to" values
        // provided by the user
        if (modeEl.value === "Range") {
          const fromEl = filterChooser.querySelector(
            `*[name="filter.${dimensionKey}.from"]`,
          );
          if (fromEl?.value) {
            filtersParams.set(fromEl.name, fromEl.value);
          }

          const toEl = filterChooser.querySelector(
            `*[name="filter.${dimensionKey}.to"]`,
          );
          if (toEl?.value) {
            filtersParams.set(toEl.name, toEl.value);
          }
        }

        // In Extract mode, set one URL param for the chosen extaction date
        // part, and another URL param for the selected values.
        if (modeEl.value === "Extract") {
          const extractEl = filterChooser.querySelector(
            `*[name="filter.${dimensionKey}.extract"]`,
          );
          filtersParams.set(extractEl.name, extractEl.value);

          const valuesSelect = filterChooser.querySelector(
            `*[name="filter.${dimensionKey}.values"]`,
          );
          if (valuesSelect?.selectedOptions.length) {
            const { selectedOptions } = valuesSelect;
            filtersParams.set(
              valuesSelect.name,
              Array.from(selectedOptions)
                .map((o) => o.value)
                .join(","),
            );
          }
        }
      }
    });

    return filtersParams.toString();
  }

  dimensionAnalysisMetricsParamsString() {
    const metricsParams = new URLSearchParams();

    const listItems = [];

    const selectedMetrics = this.metricTargets.filter((cbox) => cbox.checked);
    selectedMetrics.forEach((element) => {
      listItems.push(element.value);
    });

    if (listItems.length) {
      metricsParams.set("metrics", listItems.join(","));
    }

    return metricsParams.toString();
  }

  dimensionAnalysisGroupsParamsString() {
    const groupsParams = new URLSearchParams();

    // For each group chooser…
    this.groupChooserTargets.forEach((groupChooserTarget) => {
      // Get the element for selecting the group's dimension
      const dimensionEl = groupChooserTarget.querySelector(".dimension");

      // Get the group index for this group chooser
      const groupIndex = dimensionEl.id.split(".")[1];

      // Get the chosen dimension key
      const dimensionKey = dimensionEl.value;

      // If a dimension for this group is selected…
      if (dimensionKey) {
        // Add a URL param for the group and dimension
        groupsParams.set(dimensionEl.id, dimensionKey);

        //
        const selectedMetaCheckboxes = [
          ...groupChooserTarget.querySelectorAll(
            `div[class="meta-options-for-${dimensionKey}"] *[name="group.${groupIndex}.meta"]:checked`,
          ),
        ];

        if (selectedMetaCheckboxes.length) {
          const values = selectedMetaCheckboxes.map((el) => el.value);
          groupsParams.set(`group.${groupIndex}.meta`, values.join(","));
        }

        // Other options are based on attributes of the chosen dimension, which
        // we can get from the specific option element for that dimension
        const selectedDimensionOptionEl = dimensionEl.selectedOptions.item(0);

        // If the selected dimension is of type Timestamp…
        if (selectedDimensionOptionEl.dataset.dimensionType === "Timestamp") {
          // A mode must be selected
          const modeEl = groupChooserTarget.querySelector(
            `*[name="group.${groupIndex}.timestamp-mode"]`,
          );

          // If the mode is Extract, add a param with the chosen extraction
          // option
          if (modeEl.value === "extract") {
            const extractByEl = groupChooserTarget.querySelector(
              `*[name="group.${groupIndex}.extract"]`,
            );

            if (extractByEl.value) {
              groupsParams.set(extractByEl.name, extractByEl.value);
            }
          }

          // If the mode is Truncate, add a param with the chosen truncate
          // option
          if (modeEl.value === "truncate") {
            const truncateByEl = groupChooserTarget.querySelector(
              `*[name="group.${groupIndex}.truncate"]`,
            );

            if (truncateByEl.value) {
              groupsParams.set(truncateByEl.name, truncateByEl.value);
            }
          }

          // If the mode is Range, add a param with the values needed to define
          // the chosen ranges. There could be any number of ranges specified.
          // Add a group.N.values param with a comma delimited list of all
          // those indices.
          if (modeEl.value === "range") {
            // TODO The way these indices are collected will changed based on the
            // structure of the form elements, which is likely to change during
            // early app development

            const cont = document.querySelector(".timestamp-ranges");
            const indexInputs = Array.from(
              cont.querySelectorAll("input:not(:disabled)"),
            );
            const indices = indexInputs.map((i) => i.value || "");
            groupsParams.set(`${dimensionEl.id}.indices`, indices.join(","));
          }
        }

        // If the selection dimension is of type Duration, the user will define
        // a set of ranges by providing a set of indices. Add a group.N.values
        // param with a comma delimited list of all those indices.
        if (selectedDimensionOptionEl.dataset.dimensionType === "Duration") {
          // TODO The way these indices are collected will changed based on the
          // structure of the form elements, which is likely to change during
          // early app development
          const cont = groupChooserTarget.querySelector(".duration-ranges");
          const indexInputs = Array.from(
            cont.querySelectorAll("input:not(:disabled)"),
          );
          const indices = indexInputs.map((i) => i.value || "");
          groupsParams.set(`${dimensionEl.id}.indices`, indices.join(","));
        }
      }
    });

    return groupsParams.toString();
  }

  timeSeriesGranularityParamsString() {
    const granularityParams = new URLSearchParams();

    if (
      ["timeSeries"].includes(
        new URLSearchParams(window.location.search).get("lens"),
      )
    ) {
      if (this.hasGranularityTarget && this.granularityTarget.value) {
        granularityParams.set("granularity", this.granularityTarget.value);
      }

      if (
        this.hasGranularityTarget &&
        this.granularityTarget.value === "rolling"
      ) {
        if (this.granularityWindowTarget.value) {
          granularityParams.set("window", this.granularityWindowTarget.value);
        }
      }
    }

    return granularityParams.toString();
  }

  cumeWindowParamsString() {
    const windowParams = new URLSearchParams();

    if (
      ["cume"].includes(new URLSearchParams(window.location.search).get("lens"))
    ) {
      if (this.cumeWindowTarget.value) {
        windowParams.set("window", this.cumeWindowTarget.value);
      }
    }

    return windowParams.toString();
  }

  timeSeriesComparesParamsString() {
    const comparesParams = new URLSearchParams();

    this.compareTargets.forEach((compareTarget) => {
      const compareEl = compareTarget.querySelector("select[name=compare]");
      const lookbackEl = compareTarget.querySelector(
        "input[name=compare-lookback]",
      );

      if (compareEl?.value && lookbackEl?.value) {
        comparesParams.set(`compare.${compareEl.value}`, lookbackEl.value);
      }
    });

    return comparesParams.toString();
  }

  goto(event) {
    event.preventDefault();

    const completeParamsString = [
      lensParamsString(),
      this.rangeParamsString(),
      this.filtersParamsString(),
      this.timeSeriesGranularityParamsString(),
      this.dimensionAnalysisMetricsParamsString(),
      this.dimensionAnalysisGroupsParamsString(),
      this.timeSeriesComparesParamsString(),
      this.cumeWindowParamsString(),
    ]
      .filter((s) => s.length)
      .join("&");

    const query = cleanStringForSearchParamsString(completeParamsString);
    window.location.assign(`/data-explorer?${query}`);
  }
}
