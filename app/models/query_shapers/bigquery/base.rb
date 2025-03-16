module QueryShapers
  module Bigquery
    class Base
      ##
      # Returns all tables required to complete the query, based on parameters
      # like filters and other parameters of the base composition.
      #
      # These are logical schema tables.

      def all_tables
        # Gather all the tables required directly by filters/etc
        direct_tables = []

        # Look at each filter, and include all tables that are required by the
        # dimension.
        direct_tables.concat composition.enabled_filters.flat_map { |f| DataSchemaUtil.field_definition(f.dimension)["BigQuery"]["RequiredColumns"].keys }

        # Remove duplicates
        direct_tables.uniq!

        # Recursively gather any other tables those tables depend upon
        direct_tables.flat_map { |t| all_tables_for_table(t) }.uniq
      end

      ##
      # For all the base composition parameters (filters, etc),
      # find all the physical BigQuery columns that are required for the given
      # logical schema table name

      def columns_for_table(table_name)
        columns = []

        composition.enabled_filters.each do |filter|
          dimension_def = DataSchemaUtil.field_definition(filter.dimension)

          if dimension_def.dig("BigQuery", "RequiredColumns").key?(table_name)
            cols = dimension_def.dig("BigQuery", "RequiredColumns", table_name)
            columns.concat(cols) if cols
          end
        end

        # For each table required for this query, check to see if the given
        # table is joined to it. If it is, include the key (which will be a
        # column on the given table), or any columns required from the given
        # table to complete the join.
        all_tables.each do |t|
          table_def = DataSchema.tables[t]

          if table_def&.dig("BigQuery", "JoinsTo", table_name)&.key?("Key")
            foreign_key = table_def["BigQuery"]["JoinsTo"][table_name]["Key"]
            columns << foreign_key
          elsif table_def&.dig("BigQuery", "JoinsTo", table_name)&.key?("Expression")
            if table_def["BigQuery"]["JoinsTo"][table_name]["RequiredColumns"].key?(table_name)
              columns.concat(table_def["BigQuery"]["JoinsTo"][table_name]["RequiredColumns"][table_name])
            end
          end
        end

        columns.uniq
      end

      ##
      # For the given table, returns a list of all tables required for that
      # table to be useful in a query, including the given table itself.
      #
      # Examples
      #
      # When table_name = "downloads", since downloads has no table
      # dependencies, this returns ["downloads"].
      #
      # When table = "advertisers", the advertisers table joins to the
      # campaigns table, which joins to the impressions table, which joins to
      # the downloads table, so this returns all of those ["advertisers",
      # "campaigns", "impressions", "downloads"].
      #
      # These are logical schema tables, not physical tables in a database.

      def all_tables_for_table(table_name)
        tables = []

        table_def = DataSchema.tables[table_name]
        table_def&.dig("BigQuery", "JoinsTo")&.each do |join_table_name, join_def|
          tables.concat all_tables_for_table(join_table_name)
          tables << join_table_name
        end

        tables << table_name

        tables.uniq
      end

      ##
      # WHEREs are added from filters, and only from filters. Different types of
      # filters result in different types of WHERE clauses, to support things like
      # lists, ranges, etc. Some values in WHEREs need to be quoted.

      def wheres
        composition.enabled_filters.map do |filter|
          dimension_def = DataSchemaUtil.field_definition(filter.dimension)
          selector = dimension_def["BigQuery"]["Selector"]
          bq_type = dimension_def["BigQuery"]["Type"]

          if filter.from
            # Filters with a `from` are timestamp ranges

            # Wrap values for timestamp fields in quotes
            from = %("#{filter.abs_from}")
            to = %("#{filter.abs_to}")

            if filter.operator == :include
              "#{selector} >= #{from} AND #{selector} < #{to}"
            else
              # The parens here are important
              "(#{selector} < #{from} OR #{selector} >= #{to})"
            end
          elsif filter.gte
            # Filters with a `gte` are a duration range
            if filter.operator == :include
              "#{selector} >= #{filter.gte} AND #{selector} < #{filter.lt}"
            else
              # The parens here are important
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
      # Collect all JOIN statements needed for **all** tables required by this
      # query, not just the ones directly touched by filters, groups, etc.

      def joins
        joins = []

        all_tables.each do |table_name|
          table_def = DataSchema.tables[table_name]
          table_def&.dig("BigQuery", "JoinsTo")&.each do |join_table_name, join_def|
            join_type = table_def["BigQuery"]["Join"]
            bigquery_table_name = table_def["BigQuery"]["Table"]
            primary_key = table_def["BigQuery"]["Key"]
            foreign_key = join_def["Key"]

            # Joins can be defined using either a key on the join table that
            # matches the primary key of the input table, or using an arbitrary
            # expression
            joins << if join_def["Key"]
              "#{join_type} JOIN #{bigquery_table_name} AS #{table_name} ON #{table_name}.#{primary_key} = #{join_table_name}.#{foreign_key}"
            elsif join_def["Expression"]
              "#{join_type} JOIN #{bigquery_table_name} AS #{table_name} ON #{join_def["Expression"]}"
            else
              # This is a bit of an edge case; when neither Key nor Expression
              # are set, we JOIN without an ON. Currently this is only done to
              # handle UNNEST, which is put in the table definition's Table
              # property.
              "#{join_type} JOIN #{bigquery_table_name} AS #{table_name}"
            end
          end
        end

        joins.uniq
      end

      ##
      # Given a schema property or dimension name, returns a SELECT clause for
      # including the underlying column or data in a query.
      #
      # This is meant to be used for properties associated with groups, not for
      # selecting the group dimensions themselves. For example, things like
      # ExhibitField, SortFields, meta properties, etc.
      #
      # Takes a fingerprint that helps ensure the AS is unique, even if the
      # same column is selected for multiple purposes.

      def simple_select_for_prop_or_dim(group, prop_or_dim, fingerprint)
        field_def = DataSchemaUtil.field_definition(prop_or_dim)
        selector = field_def["BigQuery"]["Selector"]
        as = "#{group.as}_#{fingerprint}_#{prop_or_dim}"

        if field_def["Type"] == "Timestamp"
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
