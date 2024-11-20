This is a high-level overview of how the Data Explorer works – primarily its _business logic_, but some _application logic_ may creep in, since both are currently tightly integrated in a single application.

The tool is intended to allow a user to gain useful insights about their podcasts, episodes, ads, etc, by making a wide variety of queries and displaying the results in several distinct ways. The user can also interact with the displayed data to perform additional exploration, with that initial query being a starting point.

In general, this tool allows a user to make decisions about things like how to filter and group data, which data they are interested in and for what time range, and display those results as a pivot table. In some cases, the data can also be displayed as a chart.

This tool also allows the user to export queried data, such that they can do further analysis of the raw data in ways that the the tool itself may not make possible.

## Overview

The Data Explorer can operate in a number of distinct ways, which are referred to as _lenses_. The current expectation is that all lenses operate on the same set (or sets) of data.

When a user interacts with a lens, they generally are actually interacting with a _lens composition_, which is a collection of parameters that define things like which data the user is interested in, how it should be grouped, how it should be aggregated, etc. A lens composition generally turns into one or more SQL queries, and generates a data set that can be used to display data to the user in the way that they requested.

Some parameters are shared across all types of lens compositions, and some parameters are unique for the purpose of that particular lens type. For example, all lens compositions may support _filters_, but only some lens compositions may support the concept of comparing data between different periods (e.g., year-over-year comparisons).

The data that users can interact with, and the various ways in which they can do so, are defined using a lightweight schema. This schema acts as an abstraction layer, and can describe similar data that may exist in multiple underlying data stores. For example, we use BigQuery as our primary data warehouse, and the schema can describe how the Data Explorer can extract results from there. We may also use ClickHouse to store some data in a platform that is cheaper and faster to query. The schema would describe, for example, how to query episode titles from both data stores, allowing the application to decide which to query, while maintaining a consistent interface and set of features.

### Data Schema

See `doc/data_schema.md` for additional information.

The data schema primary describes two entities: **dimensions** and **metrics**. In most cases, the results presented to users will be aggregate values of some metric(s) grouped by some number of dimensions.

For example, "downloads", "downloads by country", or "downloads by country and by user agent".

The data schema defines which metrics and dimensions are available, as well as how various dimensions are related. Metrics and dimensions may be exactly or closely related to data the exists in some data store, or they may not. The schema defines how raw data from data stores should be translated, transposed, combined, etc to create the dimensions and metrics that exist in the application.

Dimensions are used for both filters and grouping. Currently it is not possible to have a dimension that is used for filtering or grouping, but not the other.

The schema also defines **properties**, which are very similar to dimensions, except they are never used for filtering or grouping.

### Base Parameters

All lens compositions support the following parameters.

#### Time Range

There is always a single **time range** that defines the core set of data that could be included in the results.

The time range has an inclusive start value, and an exclusive end value, for example:
`[2020-01-01, 2020-04-01)`. In this example, the range would include all of January, February, and March of 2020, but none of April.

Range start and end values always represent a specific instant in time, even if they appear to represent, for example, and entire day. I.e., `2020-01-01` would actually represent the instant of midnight on 2020-01-01; or `2020-01-01 12:00` would represent the instant of noon, even though visually they do not go down to the microsecond or even the hour.

Values for range start and end can be defined in two ways: absolute and relative.

Absolute values can be set using the format `YYYY-MM-DD` or `YYYY-MM-DDThh:mm:ssZ`. Relative values must use an expression supported by `Relatime`.

A range may include a mix of relative and absolute values.

When a lens composition is executed to produce results, the relative values are resolved to an absolute time for the execution. For example, `now` would resolve to the instant the composition is executed, or `now/Y` would resolve to the beginning of the current year.

#### Filters

A **filter** helps determine which data should be included in or excluded from the result.`
