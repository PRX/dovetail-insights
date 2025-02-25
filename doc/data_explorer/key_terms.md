These are definitions for how words are used internally in source code. Other words may be used in user-facing contexts, or these words may have different meanings.

- Group: For **dimensional** and **time series**, a _group_ is an abstraction that describes how data should be divided and aggregated. Each group has a property which determines the dimension used for that aggregation.

    For example, a simple case would be a group based on the podcast dimension. This would aggregate, e.g., downloads per podcast. The number of divisions is determined by the number of unique podcasts that exist in the queried data.

    In more complex cases, the group may itself define the divisions, such as when the group's dimensions is _episode publish date_. In this case, the user provides an explicit set of date/time ranges, which become the divisions.
- Group member: A _group member_ is the term used to describe the resulting divisions. For example, when grouping by podcast, if there are 100 podcasts in the resulting data, there would be 100 group members for that group. If a user defines 5 ranges on an episode publish date group, there would be 5 group members.
- Descriptor: Each group member is uniquely described by something, which may be something like an ID or UUID, a representative timestamp, or something universal like a time zone (e.g., "Europe/London"). These are called _descriptors_.

    When looking for or interacting with data related to a particular group member, we use the descriptor.
- Exhibition: Not all descriptors are suitable for displaying to users. For example, a podcast's ID would not be useful. In these cases, the data will define an alternate value (mostly) synonymous with the ID, such as the podcast's name. This is referred to as the group member's _exhibition_.

  Group member exhibitions **may not be unique**.
- Label: The label is the final display value of a group member. This may be the group member's descriptor, or exhibition if available, or some other derived value. A timestamp may be formatted in a specific way, or a value may be changed or overridden.
- Granularity: For **time series**, the term _granularity_ is used to mean _interval granularity_, and describes the length and anchor of the interval used to calculate each data point. Possible values are things like `daily`, `monthly`, `yearly`, etc.
- Interval: For **time series**, interval refers to a single slice of time for which data points are calculated. The length and anchor of each interval is defined by the _granularity_. For example, if the granularity is `daily`, any given interval will be 1 day long, and will span from midnight to midnight.

    Avoid using the term _interval_ to mean _granularity_, even though it makes sense grammatically.

    Each interval has a descriptor, similar to group members. Interval descriptors are always strings in the format "YYYY-MM-DDThh:mm:ssZ".
