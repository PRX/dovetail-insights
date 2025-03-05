module QueryShapers
  module BigQuery
    class Dimensional
      # Map Group::EXTRACT_OPTS to the BigQuery SQL version
      EXTRACT_OPTS_MAP = {
        hour: "HOUR",
        day_of_week: "DAYOFWEEK",
        day: "DAY",
        week: "WEEK",
        month: "MONTH",
        year: "YEAR"
      }
      # Map Group::TRUNCATE_OPTS to the BigQuery SQL version
      TRUNCATE_OPTS_MAP = {
        week: "WEEK",
        month: "MONTH",
        year: "YEAR"
      }

      attr_reader :composition

      def initialize(composition)
        raise unless composition.is_a? Compositions::BaseComposition

        @composition = composition
      end

      ##
      # This hash is passed to ERB#result_with_hash, and the keys will be
      # available in the ERB template as variables

      def to_hash
        @to_hash ||= {
          composition: composition,
          selects: selects,
          joins: joins,
          wheres: wheres,
          group_bys: group_bys
        }
      end

      private

      ##
      #

      def downloads_table_columns
        # TODO Look through all active filters, groups, and metrics, and find
        # all columns that will be needed on the downloads table to complete
        # the query. This needs to recursively look through the join tables
        # that filters/groups/metrics require.
      end

      ##
      #

      def impressions_table_columns
        # TODO Look through all active filters, groups, and metrics, and find
        # all columns that will be needed on the impressions table to complete
        # the query. This needs to recursively look through the join tables
        # that filters/groups/metrics require.
      end

      ##
      # Collect all JOIN statements needed for **all** tables required by this
      # query, not just the ones directly touched by filters, groups, etc.

      def joins
        tables.uniq.flat_map { |table_name| all_joins_for_table(table_name) }
      end

      ##
      # tktk

      def selects
        selects = []

        # Add SELECTs derived from the group selections and the modes they are
        # operating in
        #
        # All of these SELECTs use a unique, derived AS, so there is no risk of
        # collision, but they are not otherwise deduped, so it is currently possible
        # for things to be SELECTed more than once unnecessarily
        @composition.groups.each do |group|
          dimension_def = DataSchema.dimensions[group.dimension.to_s]
          selector = dimension_def["BigQuery"]["Selector"]

          if group.extract
            extract_arg = EXTRACT_OPTS_MAP[group.extract]
            selects << "EXTRACT(#{extract_arg} FROM #{selector}) AS #{group.as}"
          elsif group.truncate
            truncate_arg = TRUNCATE_OPTS_MAP[group.truncate]
            # Format after truncating to get a format we are anticipating.
            # All date/time descriptors should use YYYY-MM-DDThh:mm:ssZ
            selects << %(FORMAT_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", TIMESTAMP_TRUNC(#{selector}, #{truncate_arg}, "UTC"), "UTC") AS #{group.as})
          elsif group.indices
            cases = []

            group.abs_indices.each_with_index do |i, idx|
              cases << if dimension_def["BigQuery"]["Type"] == "TIMESTAMP"
                # Wrap TIMESTAMPS in quotes
                "WHEN #{selector} < '#{i}' THEN '#{group.abs_indices[idx]}'"
              else
                "WHEN #{selector} < #{i} THEN '#{group.abs_indices[idx]}'"
              end
            end

            cases << "ELSE '#{Compositions::Components::Group::TERMINATOR_INDEX}'"

            selects << "CASE \n #{cases.join("\n")} \n END AS #{group.as}"
          else
            selects << "#{selector} AS #{group.as}"
          end

          # Make additional selects for things like ExhibitProperty,
          # SortProperties, and meta properties
          selects << simple_select_for_prop_or_dim(group, dimension_def["ExhibitProperty"], :exhibit) if dimension_def["ExhibitProperty"]
          selects << dimension_def["SortProperties"].map { |p| simple_select_for_prop_or_dim(group, p, :sort) } if dimension_def["SortProperties"]
          selects << group.meta.map { |m| simple_select_for_prop_or_dim(group, m, :meta) } if group.meta
        end

        # Add a select for each metric. These are some sort of aggregation, like a
        # COUNT() of downloads
        # TODO Needs to handle variables/uniques
        @composition.metrics.each do |metric|
          metric_def = DataSchema.metrics[metric.metric.to_s]
          selector = metric_def["BigQuery"]["Selector"]

          if metric_def["Type"] && metric_def["Type"] == "Variable"

          else
            selects << "#{selector} AS #{metric.as}"
          end
        end

        selects
      end

      ##
      # WHEREs are added from filters, and only from filters. Different types of
      # filters result in different types of WHERE clauses, to support things like
      # lists, ranges, etc. Some values in WHEREs need to be quoted.

      def wheres
        @composition.filters.map do |filter|
          filter_def = DataSchema.dimensions[filter.dimension.to_s]
          selector = filter_def["BigQuery"]["Selector"]
          bq_type = filter_def["BigQuery"]["Type"]

          if filter.from
            # Filters with a `from` are timestamp ranges

            # Wrap values for timestamp fields in quotes
            from = %("#{filter.abs_from}")
            to = %("#{filter.abs_to}")

            if filter.operator == :include
              "#{selector} >= #{from} AND #{selector} < #{to}"
            else
              "(#{selector} < #{from} OR #{selector} >= #{to})"
            end
          elsif filter.gte
            # Filters with a `gte` are a duration range
            if filter.operator == :include
              "#{selector} >= #{filter.gte} AND #{selector} < #{filter.lt}"
            else
              "(#{selector} < #{filter.gte} OR #{selector} >= #{filter.lt})"
            end
          else
            # Filter on a basic list of values
            values = (bq_type == "STRING") ? filter.values.map { |v| %("#{v}") } : filter.values

            if filter.operator == :include
              # By default, only include the selected values, but if nulls=follow
              # then we also include nulls
              or_nulls = (filter.nulls == :follow) ? " OR #{selector} IS NULL" : ""
              "(#{selector} IN (#{values.join(", ")})#{or_nulls})"
            elsif filter.operator == :exclude
              # By default include nulls, but if nulls=follow then exclude them
              or_nulls = (filter.nulls == :follow) ? "" : " OR #{selector} IS NULL"
              "(#{selector} NOT IN (#{values.join(", ")})#{or_nulls})"
            end
          end
        end
      end

      ##
      # Each selected group adds a GROUP BY clause. Groups are the only source of
      # GROUP BY clauses for dimensional lens, but some dimensions add multiple
      # GROUP BY clauses, to support exhibit properties, meta properties, etc

      def group_bys
        @composition.groups.flat_map do |group|
          group_bys = [group.as]

          dimension_def = DataSchema.dimensions[group.dimension.to_s]
          group_bys << simple_group_by_for_prop_or_dim(group, dimension_def["ExhibitProperty"], :exhibit) if dimension_def["ExhibitProperty"]
          group_bys << dimension_def["SortProperties"].map { |p| simple_group_by_for_prop_or_dim(group, p, :sort) } if dimension_def["SortProperties"]
          group_bys << group.meta.map { |m| simple_group_by_for_prop_or_dim(group, m, :meta) } if group.meta

          group_bys
        end
      end

      ##
      # For a given table, returns an array of all JOIN statements necessary to
      # join that table to the downloads table. This recursively walks through the
      # schema until it gets to the downloads table.

      def all_joins_for_table(table_name)
        all_joins = []

        # All tables ultimately join to downloads, so if the input is downloads, no
        # joins are necessary
        unless table_name == "downloads"
          table_def = DataSchema.tables[table_name]
          bq = table_def["BigQuery"]

          # For each table that the input table joins so, see if any more joins are
          # needed recursively. For example, if "advertisers" is the input table,
          # it lists "campaigns" and a join, which in turn lists "impressions",
          # which finally joins to downloads. So in order to join advertisers,
          # joins for all three tables are required to get back to downloads.
          bq["JoinsTo"].each do |join_table_name, join_def|
            # As before, no joins are necessary once we're at the downloads table
            unless join_table_name == "downloads"
              all_joins.concat(all_joins_for_table(join_table_name))
            end

            # Joins can be defined using either a key on the join table that
            # matches the primary key of the input table, or using an arbitrary
            # expression
            if join_def["Key"]
              all_joins << "#{bq["Join"]} JOIN #{bq["Table"]} AS #{table_name} ON #{table_name}.#{bq["Key"]} = #{join_table_name}.#{join_def["Key"]}"
            elsif join_def["Expression"]
              all_joins << "#{bq["Join"]} JOIN #{bq["Table"]} AS #{table_name} ON #{join_def["Expression"]}"
            end
          end
        end

        all_joins
      end

      ##
      # Collect all the tables that are needed for filters, metrics, and groups.
      # This only includes the tables that are *directly* required for each of
      # these; those tables may have chained dependencies, which are handled below.

      def tables
        tables = []
        @composition.filters.each { |filter| (DataSchema.dimensions[filter.dimension.to_s]["BigQuery"]["RequiredTables"] || []).each { |t| tables << t } }
        @composition.metrics.each { |metric| (DataSchema.metrics[metric.metric.to_s]["BigQuery"]["RequiredTables"] || []).each { |t| tables << t } }
        @composition.groups.each { |group| (DataSchema.dimensions[group.dimension.to_s]["BigQuery"]["RequiredTables"] || []).each { |t| tables << t } }

        tables
      end

      ##
      # Given a schema property or dimension name, returns a SELECT clause for
      # including the underlying column or data in a query.
      #
      # This is meant to be used for properties associated with groups, not for
      # selecting the group dimensions themselves. For example, things like
      # ExhibitProperty, SortProperties, meta properties, etc.
      #
      # Takes a fingerprint that helps ensure the AS is unique, even if the
      # same column is selected for multiple purposes.

      def simple_select_for_prop_or_dim(group, prop_or_dim, fingerprint)
        property_def = DataSchema.dimensions[prop_or_dim.to_s] || DataSchema.properties[prop_or_dim.to_s]
        selector = property_def["BigQuery"]["Selector"]
        as = "#{group.as}_#{fingerprint}_#{prop_or_dim}"

        if property_def["Type"] == "Timestamp"
          # All date/time descriptors should use YYYY-MM-DDThh:mm:ssZ
          %(FORMAT_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", #{selector}, "UTC") AS #{as})
        else
          "#{selector} AS #{as}"
        end
      end

      def simple_group_by_for_prop_or_dim(group, prop_or_dim, fingerprint)
        "#{group.as}_#{fingerprint}_#{prop_or_dim}"
      end
    end
  end
end
