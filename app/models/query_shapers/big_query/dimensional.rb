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

      def initialize(composition)
        raise unless composition.is_a? Compositions::BaseComposition

        @composition = composition
      end

      def to_hash
        @to_hash ||= {
          composition: @composition,
          selects: selects,
          joins: joins,
          wheres: wheres,
          group_bys: group_bys
        }
      end

      ##
      # Collect all JOIN statements needed for **all** tables required by this
      # query, not just the ones directly touched by filters, groups, etc.

      def joins
        joins = []
        tables.uniq.each do |table_name|
          joins.concat(all_joins_for_table(table_name))
        end

        joins
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
            # All date/time group descriptors should use YYYY-MM-DDThh:mm:ssZ
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

          # Select the exhibit property for this dimension if necessary
          if dimension_def["ExhibitProperty"]
            exhibit_property_name = dimension_def["ExhibitProperty"]
            property_def = DataSchema.dimensions[exhibit_property_name] || DataSchema.properties[exhibit_property_name]
            exhibit_selector = property_def["BigQuery"]["Selector"]
            exhibit_as = "#{group.as}_exhibit_#{exhibit_property_name}"

            selects << "#{exhibit_selector} AS #{exhibit_as}"
          end

          # Select the sort properties for this dimension if necessary
          dimension_def["SortProperties"]&.each do |sort_property_name|
            property_def = DataSchema.dimensions[sort_property_name] || DataSchema.properties[sort_property_name]
            sort_selector = property_def["BigQuery"]["Selector"]
            sort_as = "#{group.as}_sort_#{sort_property_name}"

            selects << "#{sort_selector} AS #{sort_as}"
          end

          # Select each meta property that was chosen to be included
          group.meta&.each do |meta_property|
            property_def = DataSchema.dimensions[meta_property.to_s] || DataSchema.properties[meta_property.to_s]
            meta_selector = property_def["BigQuery"]["Selector"]
            meta_as = "#{group.as}_meta_#{meta_property}"

            # TODO Also need exhibit property for this property?

            selects << "#{meta_selector} AS #{meta_as}"
          end
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
      # tktk

      def wheres
        # WHEREs are added from filters, and only from filters. Different types of
        # filters result in different types of WHERE clauses, to support things like
        # lists, ranges, etc. Some values in WHEREs need to be quoted.
        wheres = []

        @composition.filters.each do |filter|
          filter_def = DataSchema.dimensions[filter.dimension.to_s]
          selector = filter_def["BigQuery"]["Selector"]
          bq_type = filter_def["BigQuery"]["Type"]

          if filter.from
            # Filters with a `from` are timestamp ranges

            # Wrap values for timestamp fields in quotes
            from = %("#{filter.abs_from}")
            to = %("#{filter.abs_to}")

            wheres << if filter.operator == :include
              "#{selector} >= #{from} AND #{selector} < #{to}"
            else
              "(#{selector} < #{from} OR #{selector} >= #{to})"
            end
          elsif filter.gte
            # Filters with a `gte` are a duration range
            wheres << if filter.operator == :include
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
              wheres << "(#{selector} IN (#{values.join(", ")})#{or_nulls})"
            elsif filter.operator == :exclude
              # By default include nulls, but if nulls=follow then exclude them
              or_nulls = (filter.nulls == :follow) ? "" : " OR #{selector} IS NULL"
              wheres << "(#{selector} NOT IN (#{values.join(", ")})#{or_nulls})"
            end
          end
        end

        wheres
      end

      ##
      # tktk

      def group_bys
        # Each selected group adds a GROUP BY clause. Groups are the only source of
        # GROUP BY clauses for dimensional lens, but some dimensions add multiple
        # GROUP BY clauses, to support exhibit properties
        group_bys = []

        # Time series have additional GROUP BY clauses for the granularity. For
        # calendar granularities, like daily/weekly/etc, one GROUP BY is added. With
        # +rolling+, an additional GROUP BY is added which is a field that contains
        # the ranges actually used to calculate the rolling windows. These ranges are
        # the source of truth, whereas the +granularity_as+ field is useful for
        # presentation, but is a less exact formatted version of the range.
        if is_a? Compositions::TimeSeriesComposition
          group_bys << "#{granularity_as}_raw" if rolling?
          group_bys << granularity_as
        end

        @composition.groups.each do |group|
          group_bys << group.as

          dimension_def = DataSchema.dimensions[group.dimension.to_s]
          if dimension_def["ExhibitProperty"]
            exhibit_property_name = dimension_def["ExhibitProperty"]
            exhibit_as = "#{group.as}_exhibit_#{exhibit_property_name}"

            group_bys << exhibit_as
          end

          dimension_def["SortProperties"]&.each do |sort_property_name|
            sort_as = "#{group.as}_sort_#{sort_property_name}"

            group_bys << sort_as
          end

          group.meta&.each do |meta_property|
            meta_as = "#{group.as}_meta_#{meta_property}"

            group_bys << meta_as
          end
        end

        group_bys
      end

      private

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
    end
  end
end
