These are definitions for how words are used internally in source code. Other words may be used in user-facing contexts, or these words may have different meanings.

- Granularity: For **time series**, the term _granularity_ is used to mean _interval granularity_, and describes the length and anchor of the interval used to calculate each data point. Possible values are things like `daily`, `monthly`, `yearly`, etc.
- Interval: For **time series**, interval refers to a single slice of time for which data points are calculated. The length and anchor of each interval is defined by the _granularity_. For example, if the granularity is `daily`, any given interval will be 1 day long, and will span from midnight to midnight.

    Avoid using the term _interval_ to mean _granularity_, even though it makes sense grammatically.
