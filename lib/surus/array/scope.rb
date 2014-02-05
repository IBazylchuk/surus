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
        where("#{connection.quote_table_name(self.table_name)}.#{connection.quote_column_name(column)} @> ARRAY[?]#{array_cast(column)}", values.flatten)
      end

      # Adds where condition that requires column to contain any values
      #
      # Examples:
      #   User.array_has_any(:permissions, "manage_users")
      #   User.array_has_any(:permissions, "manage_users", "manage_roles")
      #   User.array_has_any(:permissions, ["manage_users", "manage_roles"])
      def array_has_any(column, *values)
        where("#{connection.quote_table_name(self.table_name)}.#{connection.quote_column_name(column)} && ARRAY[?]#{array_cast(column)}", values.flatten)
      end

      # Adds where condition that requires columns at least one to contain all values
      #
      # Examples:
      #   User.arrays_have([:permissions, :roles], :and, "manage_users")
      # => SELECT * FROM "users" WHERE "users"."permissions" @> ARRAY["manage_users"]::text AND "users"."roles" @> ARRAY["manage_users"]::text;
      #   User.arrays_have([:permissions, :roles], :or, "manage_users", "manage_roles")
      # => SELECT * FROM "users" WHERE "users"."permissions" @> ARRAY["manage_users"]::text OR "users"."roles" @> ARRAY["manage_users"]::text;
      #   User.arrays_have([:permissions, :roles], :and, ["manage_users", "manage_roles"])
      # => SELECT * FROM "users" WHERE "users"."permissions" @> ARRAY["manage_users", "manage_roles"]::text AND "users"."roles" @> ARRAY["manage_users", "manage_roles"]::text;
      def arrays_have(columns, join_type, *values)
        raise "First attribute should be array. If you want find in a column, please use 'array_has'." unless columns.is_a?(::Array)
        _query = []
        _values = []
        columns.uniq.each do |column|
          _query << "#{connection.quote_table_name(self.table_name)}.#{connection.quote_column_name(column)} @> ARRAY[?]#{array_cast(column)}"
        end

        _query.count.times { _values << values.flatten }
        _join_operator = join_type == :or ? " OR " : " AND "

        where(_query.join(_join_operator), *_values)
      end

      # Adds where condition that requires column contains in array. It's analog function 'IN', but with better performance
      # https://www.datadoghq.com/2013/08/100x-faster-postgres-performance-by-changing-1-line/
      #
      # Examples:
      #   User.in_array_values(:roles, [1,2,3])
      # => SELECT * FROM "users" WHERE "users"."roles" = ANY(VALUES (1), (2), (3));
      def in_array_values(column, value)
        raise "Second attribute should be array." unless value.is_a?(::Array)
        value = value.flatten.uniq.map{ |v| "(#{v})" }.join(",")
        where("#{connection.quote_table_name(self.table_name)}.#{connection.quote_column_name(column)} = ANY(VALUES #{value})")
      end

      # Adds where condition to join conditions with OR
      #
      # Examples:
      #   User.or_conditions(User.where("id = 1"), User.where("id = 2"))
      # => SELECT * FROM users WHERE (("users"."id" = 1) OR ("users"."id" = 2));
      #   User.or_conditions(User.where("id = 1"), User.where("id = 2"), User.where("id = 3"))
      # => SELECT * FROM users WHERE (("users"."id" = 1) OR ("users"."id" = 2) OR ("users"."id" = 3));
      def or_conditions(*queries)
        _query = queries.map do |query|
          raise "Each argument should be ActiveRecord::Relation" unless query.is_a? ::ActiveRecord::Relation

          parse_query(query)
        end.join(" OR ")
        where(_query.blank? ? "1=1" : _query)
      end

      private
      def array_cast(column_name)
        column = columns_hash[column_name.to_s]
        "::#{column.sql_type}"
      end

      def parse_query(query)
        query.where_values.map do |condition|
          raise "Conditions should be only string." unless condition.is_a? ::String

          "(#{condition})"
        end.join(" AND ")
      end
    end
  end
end

ActiveRecord::Base.extend Surus::Array::Scope
