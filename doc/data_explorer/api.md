The Data Explorer does not currently have a real API, like a JSON API with endpoints to do things programatically.

This document is describing the API the frontend uses to pass things to the backend. Basically it's describing the way that URL query parameters are structured.

Special attention is paid to the URL query, because we want it to be consisent, fairly readable, and flexible for future application improvements.

This API does not strictly define the values that can be passed in. That responsiblity lies elsewhere. Any specific values that are shown below are meant to be examples only, to roughly illustrate the intended purpose of various query parameters. It also doesn't strictly define what combination of any of these possible parameters result are valid.

A frontend implementing this API should ensure that any query parameter key exists in the URL only once. Any cases where multiple values are being passed in use a single parameter (such as `metrics=downloads,impressions`; splitting across multiple parameters such as `metrics=downloads&metrics=impressions` is **not supported**).

This format was chosen over cramming a bunch of encoded JSON into a URL. There are pros and cons to both approaches.

- `lens`: The lens type identifier.
- `from`: The inclusive beginning of the time range for the lens composition's base query. Must use the format `YYYY-MM-DD`, `YYYY-MM-DDThh:mm:ssZ`, or an expression supported by `Relatime`.
- `to`: The exclusive end of the time range. Supports the same formats as `from`.
- `filter.<dimension>`: For the given dimension, indicates whether the filter operate as an `include` or `exclude`.
- `filter.<dimension>.values`: A comma-seperated list of values that impact the behavior of the filter
- `filter.<dimension>.from`: An inclusive range start value for the filter. Supports the same formats as `from`, as well as integers.
- `filter.<dimension>.to`: An exclusive range end value for the filter. Supports the same formats as `to`, as well as integers.
- `filter.<name>.extract`: A comma-separated list of values from the set of values for some date part. For example, if the date part in question were _day of week_, this may be `2,3,4,5,6`, or if the date part were _month_, this may be `10,11,12`.
- `filter.<name>.disabled`: When present, the filter is treated as disabled, the value does not matter.
- `granularity`: A value like `daily`, `weekly`, `monthly`,.
- `window`: A whole number of seconds, or a whole number of days written like `7D`.
- `metrics`: A comma-separated list of metric keys (e.g., `downloads`) and variable metric keys (e.g., `uniques(7D)`)
- `group.<N>`: The key of some dimension.
- `group.<N>.extract`: The name of date part, like `hour`, `day of week`, `month`, or `year`.
- `group.<N>.truncate`: The name of date part, like `week`, `month`, or `year`.
- `group.<N>.indices`: A comma-separated list of integers, or a comma-separated list of values in the format `YYYY-MM-DD` or `YYYY-MM-DDThh:mm:ssZ`.
- `compare.<XoX>`: A natural number, indicating the number of previous periods (`YoY`, `QoQ`, etc) to compare.

If these parameters do need to be stored or represented outside of a URL, a valid URL can be losslessly transformed into JSON (and back). Note that nearly all values are represented as strings in the JSON, even when they sometimes/always are numeric values. This is on purpose.

```json
{
  lens: "",
  from: "",
  to: "",
  granularity: "",
  window: "",
  filters:
    - dimension: "",
      disabled: true,
      operator: "",
      values: [],
      from: "",
      to: "",
      extract: [],
  groups:
    - dimension: ""
      extract: ""
      truncate: ""
      indices: []
  comparisons:
    - YoY: 0
}
```

A backend consuming either the URL or JSON variant of the API should be able to gracefully handle any sort of malformed or invalid data, and ideally provide the user a clear path to correcting the issue.
