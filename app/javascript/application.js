// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";

function doGet() {
  const params = new URLSearchParams();

  // Add the lens to the query
  const lensEl = document.querySelector("input[name=lens]:checked");
  if (lensEl?.value) {
    params.set("lens", lensEl.value);
  }

  // Add the from to the query
  const fromEl = document.querySelector("input[name=from]");
  if (fromEl?.value.trim()) {
    params.set("from", fromEl.value.trim());
  }

  // Add the to to the query
  const toEl = document.querySelector("input[name=to]");
  if (toEl?.value.trim()) {
    params.set("to", toEl.value.trim());
  }

  for (const li of Array(...document.querySelectorAll("#filters li"))) {
    const opEl = li.querySelector("select.operator");
    const valEl = li.querySelector("input.value");
    const fromEl = li.querySelector("input.from");
    const toEl = li.querySelector("input.to");
    const gteEl = li.querySelector("input.gte");
    const ltEl = li.querySelector("input.lt");

    const filterType = li.querySelector("fieldset").dataset.dimensionType;

    if (opEl?.value) {
      params.set(opEl.name, opEl.value);
    }

    if (valEl?.value) {
      // TODO Would be better if this didn't encode some characters, like comma
      params.set(valEl.name, valEl.value);
    }

    if (["Token", "String"].includes(filterType)) {
      if (fromEl?.value) {
        params.set(fromEl.name, fromEl.value);
      }
      if (toEl?.value) {
        params.set(toEl.name, toEl.value);
      }
    }

    if (["Duration"].includes(filterType)) {
      if (gteEl?.value) {
        params.set(gteEl.name, gteEl.value);
      }
      if (ltEl?.value) {
        params.set(ltEl.name, ltEl.value);
      }
    }

    if (["Timestamp"].includes(filterType)) {
      const modeSelect = li.querySelector(".timestamp-mode");
      const mode = modeSelect.value;

      if (mode === "Range") {
        if (fromEl?.value) {
          params.set(fromEl.name, fromEl.value);
        }
        if (toEl?.value) {
          params.set(toEl.name, toEl.value);
        }
      } else if (mode === "Extract") {
        const extractEl = li.querySelector(".extract select");
        if (extractEl?.value) {
          params.set(extractEl.name, extractEl.value);
        }
      }
    }
  }

  // Deal with timeSeries-specific parameters
  if (lensEl?.value === "timeSeries") {
    // Add the granularity to the query
    const granularityEl = document.querySelector("select[name=granularity]");
    if (granularityEl?.value) {
      params.set("granularity", granularityEl.value);
    }

    // Add the window to the query for rolling granularity
    const windowEl = document.querySelector("input[name=window]");
    if (granularityEl?.value === "rolling" && windowEl?.value.trim()) {
      params.set("window", windowEl.value.trim());
    }

    // Add the compare
    const compareEl = document.querySelector("select[name=compare]");
    const lookbackEl = document.querySelector("input[name=compare-lookback]");
    if (compareEl?.value && lookbackEl?.value) {
      params.set(`compare.${compareEl.value}`, lookbackEl.value);
    }
  }

  // Add groups to the query
  if (lensEl?.value === "dimensional" || lensEl?.value === "timeSeries") {
    for (const i of [1, 2]) {
      const groupEl = document.querySelector(`select[name='group.${i}']`);
      if (groupEl?.value) {
        params.set(`group.${i}`, groupEl.value);
      }

      // TODO Using a single input for these indexes during dev, this will
      // look different once the range UI is built out
      const tempRange = document.querySelector(
        `input[name='group.${i}.temp_indexes']`,
      );
      console.log(tempRange);
      if (tempRange?.value) {
        console.log(tempRange.value);
        const indexes = tempRange.value.split(",").map((v) => v.trim());
        console.log(indexes);
        params.set(`group.${i}.indices`, indexes.join(","));
      }

      const truncateEl = document.querySelector(
        `select[name='group.${i}.truncate']`,
      );
      if (truncateEl?.value) {
        params.set(`group.${i}.truncate`, truncateEl.value);
      }

      const extractEl = document.querySelector(
        `select[name='group.${i}.extract']`,
      );
      if (extractEl?.value) {
        params.set(`group.${i}.extract`, extractEl.value);
      }
    }
  }

  // Add metrics to the query
  const metrics = [];
  const metricEls = document.querySelectorAll("#metrics input[type=checkbox]");
  for (const el of Array(...metricEls)) {
    if (el.checked) {
      const metricName = el.value;

      const varsEl = document.querySelector(
        `input[name="${metricName}.variables"]`,
      );
      if (varsEl?.value) {
        const vars = varsEl.value.split(",").map((v) => v.trim());
        metrics.push(vars.map((v) => `${metricName}(${v})`));
      } else {
        metrics.push(el.value);
      }
    }
  }
  if (metrics.length) {
    params.set("metrics", metrics.join(","));
  }

  // URLSearchParams.toString() encodes some characters that don't need to be,
  // and these are meaningful characters in our URLs, which are beneficial to
  // keep as literals. For example, if we did `params.set` for a value that
  // included commas, the commas would be encoded, but we'd prefer to have them
  // as literal commas in the final URL.
  //
  // So we force some of those encoded characters back to the original
  // characters.
  //
  // We do this with plus signs, since plus signs can appear in relative time
  // expresssions. But note that converting those back to literal plus signs in
  // the URL means that they will be interpreted as **spaces**, since a plus
  // sign in a URL query always represents an encoded space. We still do this
  // to maintain readability of the URL, and handle spaces as a special case in
  // the from and to query parameters on the server side. See
  // BaseLensComposition#from= for more info.
  //
  // TODO Currently this decodes plus signs for all params, but we only handle
  // plus signs specially on the server for from and to, so that could cause
  // problems. This should only decode them for from and to.
  const paramString = params.toString();
  const recodedString = paramString
    .replaceAll("%2F", "/")
    .replaceAll("%2C", ",")
    .replaceAll("%2B", "+");

  window.location.assign(`/?${recodedString}`);
}

function hotkeys(e) {
  if (e.metaKey && e.key === "Enter") {
    e.preventDefault();

    doGet();
  }
}

function highlight(ev) {
  const tbl = document.querySelector("#results table");

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

// TODO Move this somewhere else
// TODO Also probably make this do things with turbo
// This takes over handling the submission of the form for the data explorer.
// We want the URL that is produced to be as minimal/clean/readable as possible,
// and using the browser's native GET request for the form is not sufficient.
(async function () {
  document.addEventListener("DOMContentLoaded", async (_) => {
    const form = document.getElementById("data-explorer");

    if (form) {
      form.addEventListener("submit", (ev) => {
        // Don't let the browser submit the form
        ev.preventDefault();

        doGet();
      });
    }

    document.getElementById("highlight").addEventListener("change", highlight);

    highlight();

    document.onkeydown = hotkeys;
  });
})();
