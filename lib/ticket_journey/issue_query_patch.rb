module TicketJourney
  module IssueQueryPatch
    def available_filters
      # Let Redmine and legacy alias-based plugins finish initialization first.
      # Wrapping initialize_available_filters with prepend can make their saved
      # aliases call back into our wrapper indefinitely.
      filters = super
      unless filters.key?('tj_return_count')
        add_available_filter('tj_return_count', type: :integer, label: :field_tj_return_count)
      end
      filters
    end

    def sql_for_tj_return_count_field(field, operator, values)
      expression = ReturnCount.sql
      return "#{expression} > 0" if operator == '*'
      return "#{expression} = 0" if operator == '!*'

      # Delegate numeric validation and operators to Redmine's query builder.
      values = values.first.to_s.scan(/[+-]?\d+/).map(&:to_i) if operator == '!'
      sql_for_field(field, operator, values, Issue.table_name, 'id')
        .gsub("#{Issue.table_name}.id", expression)
    end

    def issues(options = {})
      result = super
      ReturnCount.preload(result) if has_column?(:tj_return_count)
      result
    end
  end
end
