# Calculation rules for Performance Section 1. No writes or stored counters.
class TicketJourneyPerformance
  BATCH_SIZE = 100
  TREND_MONTHS = 5

  def self.completed_month_ends(date)
    TREND_MONTHS.downto(1).map { |months| (date.beginning_of_month << (months - 1)) - 1 }
  end

  def self.delivery_trend_points(date)
    completed_month_ends(date).map do |day|
      { date: day, window_start: day.beginning_of_month << 2,
        due: 0, done: 0, due_weight: 0.0, done_weight: 0.0,
        delivered_count: 0, delivered_weight: 0.0, missing_completion: 0 }
    end
  end

  def self.add_delivery_trend_row!(point, row)
    return unless delivery_eligible?(row)

    if row[:done] && row[:delivered_at].nil?
      point[:missing_completion] += 1
    end
    if monthly_delivery?(row, point[:window_start], point[:date])
      point[:delivered_count] += 1
      point[:delivered_weight] += row[:weight]
    end
    return unless delivery_due?(row, point[:date])

    point[:due] += 1
    point[:due_weight] += row[:weight]
    if row[:done]
      point[:done] += 1
      point[:done_weight] += row[:weight]
    end
  end

  def self.monthly_delivery?(row, first_day, last_day)
    delivery_eligible?(row) && row[:done] && row[:delivered_at] && row[:delivered_at].between?(first_day, last_day)
  end

  def self.finish_output_trend!(points, owner_count)
    points.each do |point|
      point[:monthly_count] = point[:delivered_count] / 3.0 / owner_count
      point[:monthly_weight] = point[:delivered_weight] / 3.0 / owner_count
    end
  end

  def self.delivery_eligible?(row)
    row && !DELIVERY_EXCLUDED_STATUSES.include?(row[:status_name].to_s.strip)
  end

  def self.delivery_due?(row, date)
    delivery_eligible?(row) && row[:due] && row[:due] <= date
  end

  def self.finish_delivery_trend!(points)
    points.each do |point|
      point[:count_ratio] = point[:due].positive? ? point[:done] * 100.0 / point[:due] : nil
      point[:weight_ratio] = point[:due_weight].positive? ? point[:done_weight] * 100.0 / point[:due_weight] : nil
    end
  end
  DETAIL_SORT_KEYS = %w[id subject status due weight completion].freeze
  DETAIL_COLUMNS = {
    'id' => 'Ticket', 'project' => 'Project (current)', 'subject' => 'Title / Subject (current)',
    'tracker' => 'Tracker (current)', 'owner' => 'Ticket Owner (as of date)',
    'status' => 'Status (as of date)', 'due' => 'Due Date (current)',
    'weight' => 'Complexity Weight (current)', 'completion' => 'Last Recorded Completion by Report Date',
    'priority' => 'Priority (current)', 'estimate' => 'PM Estimate (current)',
    'spent' => 'Time Spent (visible lifetime)'
  }.freeze
  DEFAULT_DETAIL_COLUMNS = (DETAIL_COLUMNS.keys - %w[priority estimate spent]).freeze
  DETAIL_GROUPS = { 'project' => :project_name, 'tracker' => :tracker_name,
                    'owner' => :owner_name, 'status' => :status_name }.freeze

  def self.detail_sort_options(metric, sort, direction)
    default = if %w[done delivered delivered_weight].include?(metric)
                ['completion', 'desc']
              elsif metric.start_with?('missing_')
                ['id', 'asc']
              else
                ['due', 'asc']
              end
    return default unless DETAIL_SORT_KEYS.include?(sort)
    [sort, %w[asc desc].include?(direction) ? direction : 'asc']
  end

  def self.sort_details(rows, key, direction, group_by: nil)
    field = { 'id' => :id, 'subject' => :subject, 'status' => :status_name,
              'due' => :due, 'weight' => :weight, 'completion' => :delivered_at }.fetch(key)
    rows.sort do |left, right|
      if DETAIL_GROUPS.key?(group_by)
        group = detail_group_key(left, group_by) <=> detail_group_key(right, group_by)
        next group unless group.zero?
      end
      a = field == :weight && left[:missing_weight] ? nil : left[field]
      b = field == :weight && right[:missing_weight] ? nil : right[field]
      a = a.downcase if a.is_a?(String)
      b = b.downcase if b.is_a?(String)
      # Missing dates/weights stay last in either direction. ID is a stable tie
      # breaker so page boundaries do not shuffle on repeated requests.
      comparison = if a.nil? || b.nil?
                     (a.nil? ? 1 : 0) <=> (b.nil? ? 1 : 0)
                   else
                     (a <=> b) * (direction == 'desc' ? -1 : 1)
                   end
      comparison.zero? ? left[:id] <=> right[:id] : comparison
    end
  end

  def self.detail_group_key(row, group_by)
    field = DETAIL_GROUPS[group_by]
    return nil unless field

    [row[field].to_s.downcase, group_by == 'project' ? row[:project_id] : row[field].to_s]
  end
  HistoryDetail = Struct.new(:property, :prop_key, :old_value, :value, :id)
  HistoryJournal = Struct.new(:id, :created_on, :details)
  FieldValue = Struct.new(:custom_field, :value)

  def self.batch_field_values(batch, field_ids: [57, 70])
    # Standard Redmine visibility uses field availability plus visible_by?. If
    # another plugin overrides the issue-level visibility method, keep its path
    # instead of assuming that our two-field shortcut covers its extra rules.
    native = batch.all? do |issue|
      location = issue.method(:visible_custom_field_values).source_location&.first.to_s.tr('\\', '/')
      location == Rails.root.join('app/models/issue.rb').to_s.tr('\\', '/')
    end
    unless native
      ActiveRecord::Associations::Preloader.new(records: batch, associations: :custom_values).call
      return batch.to_h { |issue| [issue.id, issue.visible_custom_field_values] }
    end
    raw = Hash.new { |hash, id| hash[id] = {} }
    CustomValue.where(customized_type: 'Issue', customized_id: batch.map(&:id), custom_field_id: field_ids)
               .pluck(:customized_id, :custom_field_id, :value).each do |id, field_id, value|
      raw[id][field_id] = value
    end
    batch.to_h do |issue|
      fields = issue.available_custom_fields.select { |field| field_ids.include?(field.id) && field.visible_by?(issue.project, User.current) }
      [issue.id, fields.map { |field| FieldValue.new(field, raw[issue.id][field.id]) }]
    end
  end

  # A broad SQL candidate set, followed by exact historical reconstruction.
  # Current-owner-only filtering would lose tickets reassigned after report date.
  def self.candidate_scope(scope, owner_ids)
    scoped_ids = scope.reselect('issues.id').unscope(:order)
    current = CustomValue.where(customized_type: 'Issue', custom_field_id: 57, value: owner_ids,
                                customized_id: scoped_ids).select(:customized_id)
    history = JournalDetail.joins(:journal)
      .where(journals: { journalized_type: 'Issue', journalized_id: scoped_ids }, property: 'cf', prop_key: '57')
      .where('journal_details.old_value IN (?) OR journal_details.value IN (?)', owner_ids, owner_ids)
      .select('journals.journalized_id')
    scope.where(id: current).or(scope.where(id: history))
  end

  # Restrict only by current due dates, which are also what report calculations
  # use. Do not prefilter current status: it may differ from the as-of status.
  def self.metric_scope(scope, metric, date)
    case metric
    when 'started', 'untouched'
      scope.where('issues.due_date < ?', date)
    when 'due', 'done'
      scope.where('issues.due_date <= ?', date)
    when 'due_soon'
      scope.where(due_date: date...(date + 3))
    when 'missing_due'
      scope.where(due_date: nil)
    else
      scope
    end
  end

  def self.owner_at(issue, changes, date, owner_value: nil)
    value = owner_value.nil? ? issue.custom_value_for(57)&.value.to_s : owner_value
    changes.reverse_each do |journal|
      next unless journal.created_on > date.in_time_zone.end_of_day
      journal.details.each do |detail|
        value = detail.old_value.to_s if detail.property == 'cf' && detail.prop_key == '57'
      end
    end
    value
  end
  TRACKERS = ['Bug', 'Change Request / Improvement', 'Feature', 'Task (Business Jobs)'].freeze
  # Hadi's rule: only having been In Progress establishes started work.
  # Later workflow stages, logged time and comments are not substitutes.
  STARTED = ['In Progress', 'Inprogress'].freeze
  # Hadi's latest rule excludes these from Section 1 only, using as-of status.
  OPEN_EXCLUDED_STATUSES = ['New', 'On-Hold'].freeze
  STOPPED = ['Pending'].freeze
  DELIVERY_EXCLUDED_STATUSES = ['Archived', 'Ongoing'].freeze
  DETAIL_LABELS = {
    'open' => 'Total Open Tickets', 'not_overdue' => 'Not Overdue Open Tickets',
    'started' => 'Overdue - Already Started', 'untouched' => 'Overdue - Not Touched',
    'stopped' => 'Stopped Open Tickets (Pending)',
    'due_soon' => 'Due Soon', 'missing_due' => 'Open Tickets Without Due Dates',
    'missing_weight' => 'Tickets Without Usable Complexity Weight',
    'missing_delivery' => 'Done Tickets Without Recorded Completion Dates',
    'done' => 'Done Tickets Due by Date', 'due' => 'Tickets Due by Date',
    'delivered' => 'Monthly Ticket Count Contributors',
    'delivered_weight' => 'Monthly Complexity Weight Contributors'
  }.freeze

  # Fetch scalar changes only: journal notes and unrelated fields can dwarf the
  # report data. Future owner changes are needed to rewind reassigned tickets;
  # all status changes are needed for started/completion and historical status.
  def self.history_for(issue_ids, date, owner_only: false, include_return_reason: false)
    result = Hash.new { |hash, id| hash[id] = [] }
    journals = {}
    scope = JournalDetail.joins(:journal)
      .where(journals: { journalized_type: 'Issue', journalized_id: issue_ids })
    scope = if owner_only
              scope.where(property: 'cf', prop_key: '57').where('journals.created_on > ?', date.in_time_zone.end_of_day)
            else
              scope.where("(journal_details.property = ? AND journal_details.prop_key = ?) OR (journal_details.property = ? AND journal_details.prop_key = ? AND journals.created_on > ?)",
                          'attr', 'status_id', 'cf', '57', date.in_time_zone.end_of_day)
            end
    if include_return_reason && !owner_only
      reason_scope = JournalDetail.joins(:journal).where(journals: { journalized_type: 'Issue', journalized_id: issue_ids }, property: 'cf', prop_key: '66')
      scope = scope.or(reason_scope)
    end
    scope.order('journals.created_on', 'journals.id', 'journal_details.id')
      .pluck('journals.journalized_id', 'journals.id', 'journals.created_on',
             'journal_details.property', 'journal_details.prop_key', 'journal_details.old_value', 'journal_details.value', 'journal_details.id')
      .each do |issue_id, journal_id, created_on, property, key, old_value, value, detail_id|
        journal = journals[journal_id] ||= begin
          entry = HistoryJournal.new(journal_id, created_on, [])
          result[issue_id] << entry
          entry
        end
        journal.details << HistoryDetail.new(property, key, old_value, value, detail_id)
      end
    result
  end

  def self.snapshot(issue, date, statuses, history: nil, visible_values: nil, owner_value: nil)
    cutoff = date.in_time_zone.end_of_day
    return if issue.created_on > cutoff

    status_id = issue.status_id.to_s
    owner_id = owner_value.nil? ? issue.custom_value_for(57)&.value.to_s : owner_value
    changes = (history || issue.journals).sort_by { |j| [j.created_on, j.id] }
    # Reverse later changes, including explicit blank owners; only absent history
    # falls back to today's value. Due date and weight intentionally stay current.
    changes.reverse_each do |journal|
      next unless journal.created_on > cutoff
      journal.details.each do |detail|
        status_id = detail.old_value.to_s if detail.property == 'attr' && detail.prop_key == 'status_id'
        owner_id = detail.old_value.to_s if detail.property == 'cf' && detail.prop_key == '57'
      end
    end
    status = statuses[status_id]
    started = STARTED.include?(status&.name.to_s.strip)
    delivered_at = nil
    changes.each do |journal|
      next if journal.created_on > cutoff
      journal.details.each do |detail|
        next unless detail.property == 'attr' && detail.prop_key == 'status_id'
        old_name = statuses[detail.old_value.to_s]&.name.to_s.strip
        new_name = statuses[detail.value.to_s]&.name.to_s.strip
        started ||= STARTED.include?(old_name) || STARTED.include?(new_name)
        delivered_at = journal.created_on.in_time_zone.to_date if new_name == 'Done / Closed' && old_name != new_name
      end
    end
    weight_value = (visible_values || issue.visible_custom_field_values).find { |v| v.custom_field.id == 70 }&.value
    weight = weight_value.to_s.tr(',', '.').to_f
    valid_weight = weight.finite? && weight.positive?
    {
      id: issue.id, owner_id: owner_id, due: issue.due_date, start_date: issue.start_date, status_name: status&.name.to_s.strip,
      open: status && !status.is_closed, done: status&.name.to_s.strip == 'Done / Closed',
      started: started, delivered_at: delivered_at,
      weight: valid_weight ? weight : 0.0, missing_weight: !valid_weight
    }
  end

  def self.calculate(rows, date, _legacy_start_date = nil)
    open = rows.select { |r| r[:open] && !OPEN_EXCLUDED_STATUSES.include?(r[:status_name].to_s.strip) }
    not_overdue, overdue = open.partition { |r| r[:due].nil? || r[:due] >= date }
    started, untouched = overdue.partition { |r| r[:started] }
    # Section 2 alone excludes these as-of statuses. Do not filter the input
    # rows globally: Ongoing still belongs to Section 1's open population.
    delivery_rows = rows.select { |r| delivery_eligible?(r) }
    due = delivery_rows.select { |r| delivery_due?(r, date) }
    done = due.select { |r| r[:done] }
    # Same three complete calendar months for both monthly metrics. The report
    # month is excluded; zero-delivery months still count in the denominator.
    # The legacy third argument is intentionally ignored for old callers.
    monthly_end = date.beginning_of_month - 1
    monthly_start = date.beginning_of_month << 3
    delivered = delivery_rows.select { |r| monthly_delivery?(r, monthly_start, monthly_end) }
    weighted_delivered = delivered.select { |r| r[:weight].positive? }
    # Both counts and drill-downs use these exact sets; never rebuild them with
    # current-status IssueQuery filters for a historical report.
    sets = {
      'open' => open, 'not_overdue' => not_overdue, 'started' => started, 'untouched' => untouched,
      'stopped' => open.select { |r| STOPPED.include?(r[:status_name].to_s.strip) },
      'due_soon' => not_overdue.select { |r| r[:due] && (r[:due] - date).to_i < 3 },
      'missing_due' => open.select { |r| r[:due].nil? },
      'missing_weight' => rows.select { |r| r[:missing_weight] },
      'missing_delivery' => delivery_rows.select { |r| r[:done] && r[:delivered_at].nil? },
      'done' => done, 'due' => due, 'delivered' => delivered, 'delivered_weight' => weighted_delivered
    }
    {
      detail_sets: sets,
      groups: [open, not_overdue, started, untouched], due: due, done: done,
      due_soon: sets['due_soon'].size,
      stopped: sets['stopped'].size,
      missing_due: sets['missing_due'].size, missing_weight: sets['missing_weight'].size,
      missing_delivery: sets['missing_delivery'].size,
      monthly_count: delivered.size / 3.0,
      monthly_start_date: monthly_start, monthly_end_date: monthly_end,
      monthly_weight: weight(weighted_delivered) / 3.0
    }
  end

  def self.weight(rows)
    rows.sum { |row| row[:weight] }
  end

  def self.average_targets(values)
    return nil if values.empty? || values.any? { |value| !value.is_a?(Numeric) || !value.finite? || !value.positive? }

    values.sum.to_f / values.size
  end

end
