require 'set'

module TicketJourney
  module ReturnCount
    COUNTER_ROLES = { C1: :feedback, C2: :review, C3: :ready_merge, C4: :final_check, C5: :done }.freeze

    module_function

    def status_role(name)
      normalized = name.to_s.strip.downcase
      TicketJourneyController::STATUS_NAMES.each do |role, names|
        return role if names.any? { |value| value.downcase == normalized }
      end
      :unknown
    end

    def events(family, transitions)
      keys = TicketJourneyController::FAMILY_COUNTER_KEYS.fetch(family.to_sym, [])
      seen = Set.new
      transitions.each_with_object([]) do |transition, result|
        next if transition[:synthetic] || status_role(transition[:to_status]) != :returned
        key = COUNTER_ROLES.key(status_role(transition[:from_status]))
        next unless key && keys.include?(key)
        detail_id = transition[:journal_detail_id]
        next if detail_id && !seen.add?(detail_id)

        result << transition.merge(counter_key: key, return_number: result.size + 1)
      end
    end

    # A correlated expression supports native query filtering and sorting without
    # storing a second copy of the journal history or changing issue records.
    def sql
      connection = Issue.connection
      config = TicketJourneyController
      issue_table = Issue.table_name
      tracker_table = Tracker.table_name
      status_table = IssueStatus.table_name
      mysql = connection.adapter_name.match?(/mysql|trilogy/i)
      cast_type = mysql ? 'CHAR' : 'TEXT'
      tracker_name_field = mysql ? 'BINARY name' : 'name'
      quote_list = ->(values) { values.map { |value| connection.quote(value) }.join(', ') }
      status_condition = lambda do |alias_name, roles|
        names = roles.flat_map { |role| config::STATUS_NAMES.fetch(role, []) }.map(&:downcase).uniq
        names.empty? ? '1=0' : "LOWER(TRIM(#{alias_name}.name)) IN (#{quote_list.call(names)})"
      end
      non_internal_names = config::TRACKER_FAMILY_DEFINITIONS.reject { |family, _| family == :internal }
                                .values.flat_map { |definition| definition[:tracker_names] }
      family_conditions = config::FAMILY_COUNTER_KEYS.filter_map do |family, keys|
        next if keys.empty?
        tracker_names = family == :internal ? non_internal_names : config::TRACKER_FAMILY_DEFINITIONS.fetch(family)[:tracker_names]
        tracker_condition =
          if tracker_names.empty?
            family == :internal ? '1=1' : '1=0'
          else
            operator = family == :internal ? 'NOT IN' : 'IN'
            "#{issue_table}.tracker_id #{operator} (SELECT id FROM #{tracker_table} WHERE #{tracker_name_field} IN (#{quote_list.call(tracker_names)}))"
          end
        roles = keys.map { |key| COUNTER_ROLES.fetch(key) }
        "(#{tracker_condition} AND #{status_condition.call('tj_return_from', roles)})"
      end
      families = family_conditions.empty? ? '1=0' : family_conditions.join(' OR ')

      <<~SQL.squish
        (SELECT COUNT(DISTINCT tj_return_detail.id)
         FROM #{Journal.table_name} tj_return_journal
         INNER JOIN #{JournalDetail.table_name} tj_return_detail
           ON tj_return_detail.journal_id = tj_return_journal.id
         INNER JOIN #{status_table} tj_return_from
           ON CAST(tj_return_from.id AS #{cast_type}) = tj_return_detail.old_value
         INNER JOIN #{status_table} tj_return_to
           ON CAST(tj_return_to.id AS #{cast_type}) = tj_return_detail.value
         WHERE tj_return_journal.journalized_type = 'Issue'
           AND tj_return_journal.journalized_id = #{issue_table}.id
           AND tj_return_detail.property = 'attr'
           AND tj_return_detail.prop_key = 'status_id'
           AND #{status_condition.call('tj_return_to', [:returned])}
           AND (#{families}))
      SQL
    end

    def preload(issues)
      ids = issues.map(&:id).compact
      return if ids.empty?
      counts = Issue.where(id: ids).pluck(:id, Arel.sql(sql)).to_h
      issues.each { |issue| issue.instance_variable_set(:@tj_return_count, counts.fetch(issue.id, 0).to_i) }
    end
  end
end
