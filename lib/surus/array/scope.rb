module Surus
  module Array
    module Scope
      # Adds where condition that requires column to contain all values
      #
      # Examples:
      #   User.array_has(:permissions, "manage_users")
      #   User.array_has(:permissions, "manage_users", "manage_roles")
      #   User.array_has(:permissions, ["manage_users", "manage_roles"])
      def array_has(column, *values)
        where("#{connection.quote_column_name(column)} @> ARRAY[?]#{array_cast(column)}", values.flatten)
      end

      # Adds where condition that requires column to contain any values
      #
      # Examples:
      #   User.array_has_any(:permissions, "manage_users")
      #   User.array_has_any(:permissions, "manage_users", "manage_roles")
      #   User.array_has_any(:permissions, ["manage_users", "manage_roles"])
      def array_has_any(column, *values)
        where("#{connection.quote_column_name(column)} && ARRAY[?]#{array_cast(column)}", values.flatten)
      end

      # Adds where condition that requires columns at least one to contain all values
      #
      # Examples:
      #   User.arrays_have([:permissions, :roles], :and, "manage_users")
      #   User.arrays_have([:permissions, :roles], :or, "manage_users", "manage_roles")
      #   User.arrays_have([:permissions, :roles], :and, ["manage_users", "manage_roles"])
      def arrays_have(columns, join_type, *values)
        raise "Should be array in first attribute. If you want find in a column, please use 'array_has'." unless columns.is_a?(::Array)
        _query = []
        _values = []
        columns.uniq.each do |column|
          _query << "#{connection.quote_column_name(column)} @> ARRAY[?]#{array_cast(column)}"
        end

        _query.count.times { _values << values.flatten }
        _join_operator = join_type == :or ? " OR " : " AND "

        where(_query.join(_join_operator), *_values)
      end

      private
      def array_cast(column_name)
        column = columns_hash[column_name.to_s]
        "::#{column.sql_type}"
      end
    end
  end
end

ActiveRecord::Base.extend Surus::Array::Scope
