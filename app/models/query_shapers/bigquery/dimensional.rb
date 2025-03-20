module QueryShapers
  module Bigquery
    class Dimensional < Base
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
          abs_from: composition.abs_from,
          abs_to: composition.abs_to,
          selects: selects,
          joins: joins,
          wheres: wheres,
          group_bys: group_bys,
          downloads_table_columns: columns_for_table("downloads"),
          impressions_table_columns: columns_for_table("impressions")
        }
      end

      private

      ##
      # Returns all tables required to complete the query, based on parameters
      # like filters, groups, and metrics.

      def all_tables
        all_tables = super

        # Gather all the tables required directly by dimensional parameters,
        # like metrics, and groups
        direct_tables = []

        # Look at each metric, and include all tables that are required
        direct_tables.concat composition.metrics.flat_map { |m| DataSchema.metrics[m.metric.to_s]["BigQuery"]["RequiredColumns"].keys }

        # Look at each group, and include all tables that are required by the
        # group dimension, by the exhibit property, and by any meta properties
        if @composition.groups
          direct_tables.concat(composition.groups.flat_map do |group|
            tables = []

            dimension_def = DataSchemaUtil.field_definition(group.dimension)
            tables.concat dimension_def["BigQuery"]["RequiredColumns"].keys

            if dimension_def["ExhibitField"]
              exhibit_def = DataSchemaUtil.field_definition(dimension_def["ExhibitField"])
              tables.concat exhibit_def["BigQuery"]["RequiredColumns"].keys
            end

            group&.meta&.each do |meta_name|
              meta_def = DataSchemaUtil.field_definition(meta_name)
              tables.concat meta_def["BigQuery"]["RequiredColumns"].keys
            end

            tables
          end)
        end

        # Remove duplicates
        direct_tables.uniq!

        # Recursively gather any other tables those tables depend upon
        all_tables.concat direct_tables.flat_map { |t| all_tables_for_table(t) }.uniq
      end

      def columns_for_table(table_name)
        columns = super

        # TODO Lots of duplication in here, and this is very similar to the
        # cume implementation can it be DRYed up?

        composition.metrics.each do |metric|
          metric_def = DataSchema.metrics[metric.metric.to_s]

          if metric_def.dig("BigQuery", "RequiredColumns").key?(table_name)
            cols = metric_def.dig("BigQuery", "RequiredColumns", table_name)
            columns.concat(cols) if cols
          end
        end

        composition&.groups&.each do |group|
          dimension_def = DataSchemaUtil.field_definition(group.dimension)

          if dimension_def.dig("BigQuery", "RequiredColumns").key?(table_name)
            cols = dimension_def.dig("BigQuery", "RequiredColumns", table_name)
            columns.concat(cols) if cols
          end

          exhibit_name = dimension_def["ExhibitField"]
          if exhibit_name
            exhibit_def = DataSchemaUtil.field_definition(exhibit_name)
            if exhibit_def.dig("BigQuery", "RequiredColumns").key?(table_name)
              cols = exhibit_def.dig("BigQuery", "RequiredColumns", table_name)
              columns.concat(cols) if cols
            end
          end

          dimension_def["SortFields"]&.each do |sort_field_name|
            sort_def = DataSchemaUtil.field_definition(sort_field_name)
            if sort_def.dig("BigQuery", "RequiredColumns").key?(table_name)
              cols = sort_def.dig("BigQuery", "RequiredColumns", table_name)
              columns.concat(cols) if cols
            end
          end

          group&.meta&.each do |meta_field_name|
            field_def = DataSchemaUtil.field_definition(meta_field_name)

            if field_def.dig("BigQuery", "RequiredColumns").key?(table_name)
              cols = field_def.dig("BigQuery", "RequiredColumns", table_name)
              columns.concat(cols) if cols
            end
          end
        end

        columns.uniq
      end

      def group_selects
        selects = []

        # Add SELECTs derived from the group selections and the modes they are
        # operating in
        #
        # All of these SELECTs use a unique, derived AS, so there is no risk of
        # collision, but they are not otherwise deduped, so it is currently possible
        # for things to be SELECTed more than once unnecessarily
        @composition.groups&.each do |group|
          dimension_def = DataSchemaUtil.field_definition(group.dimension)
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

            selects << "CASE \n\t\t#{cases.join("\n\t\t")}\n\t\tEND AS #{group.as}"
          else
            selects << "#{selector} AS #{group.as}"
          end

          # Make additional selects for things like ExhibitField,
          # SortFields, and meta properties
          selects << simple_select_for_prop_or_dim(group, dimension_def["ExhibitField"], :exhibit) if dimension_def["ExhibitField"]
          selects.concat dimension_def["SortFields"].map { |p| simple_select_for_prop_or_dim(group, p, :sort) } if dimension_def["SortFields"]
          selects.concat group.meta.map { |m| simple_select_for_prop_or_dim(group, m, :meta) } if group.meta
        end

        selects
      end

      ##
      # Returns the SELECT statements needed to compute the results of the
      # composition's chosen metrics

      def metric_selects
        selects = []

        composition.metrics.each do |metric|
          metric_def = DataSchema.metrics[metric.metric.to_s]
          selector = metric_def["BigQuery"]["Selector"]

          if metric_def["Type"] && metric_def["Type"] == "Variable"
            # TODO
          else
            selects << "#{selector} AS #{metric.as}"
          end
        end

        selects
      end

      ##
      # Returns an array of strings, where each string is part of a SELECT
      # statement in the query, like ["foo AS bar", "name AS full_name"].

      def selects
        selects = []

        selects.concat group_selects
        selects.concat metric_selects

        selects.uniq
      end

      ##
      # Each selected group adds a GROUP BY clause. Groups are the only source of
      # GROUP BY clauses for dimensional lens, but some dimensions add multiple
      # GROUP BY clauses, to support exhibit properties, meta properties, etc

      def group_bys
        composition&.groups&.flat_map do |group|
          # Always GROUP BY the group's dimension, using the unique AS value
          group_bys = [group.as]

          # The group's dimension may bring along some additonal columns that
          # get SELECTed, like an exhibit property or sort property. Since they
          # are being SELECTed, we also have to GROUP them.
          dimension_def = DataSchemaUtil.field_definition(group.dimension)
          group_bys << simple_group_by_for_prop_or_dim(group, dimension_def["ExhibitField"], :exhibit) if dimension_def["ExhibitField"]
          group_bys << dimension_def["SortFields"].map { |p| simple_group_by_for_prop_or_dim(group, p, :sort) } if dimension_def["SortFields"]

          # Similarly, additional columns may be chosen to include in the
          # results (static properties of the group's dimension), which will be
          # SELECTed and thus must be GROUPed.
          group_bys << group.meta.map { |m| simple_group_by_for_prop_or_dim(group, m, :meta) } if group.meta

          group_bys
        end
      end
    end
  end
end
