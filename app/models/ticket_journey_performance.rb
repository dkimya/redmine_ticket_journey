# Calculation rules for Performance Section 1. No writes or stored counters.
class TicketJourneyPerformance
  BATCH_SIZE = 100
  DETAIL_SORT_KEYS = %w[id subject status due weight completion].freeze
  DETAIL_COLUMNS = {
    'id' => 'Ticket', 'project' => 'Project (current)', 'subject' => 'Subject (current)',
    'tracker' => 'Tracker (current)', 'owner' => 'Ticket Owner (as of date)',
    'status' => 'Status (as of date)', 'due' => 'Due Date (current)',
    'weight' => 'Complexity Weight (current)', 'completion' => 'Last Recorded Completion by Report Date'
  }.freeze
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
  HistoryDetail = Struct.new(:property, :prop_key, :old_value, :value)
  HistoryJournal = Struct.new(:id, :created_on, :details)
  FieldValue = Struct.new(:custom_field, :value)

  def self.batch_field_values(batch)
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
    CustomValue.where(customized_type: 'Issue', customized_id: batch.map(&:id), custom_field_id: [57, 70])
               .pluck(:customized_id, :custom_field_id, :value).each do |id, field_id, value|
      raw[id][field_id] = value
    end
    batch.to_h do |issue|
      fields = issue.available_custom_fields.select { |field| [57, 70].include?(field.id) && field.visible_by?(issue.project, User.current) }
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
  STOPPED = ['On-Hold', 'Pending'].freeze
  DELIVERY_EXCLUDED_STATUSES = ['Archived', 'Ongoing'].freeze
  DETAIL_LABELS = {
    'open' => 'Total Open Tickets', 'not_overdue' => 'Not Overdue Open Tickets',
    'started' => 'Overdue - Already Started', 'untouched' => 'Overdue - Not Touched',
    'stopped' => 'Stopped Open Tickets (On-Hold / Pending)',
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
  def self.history_for(issue_ids, date, owner_only: false)
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
    scope.order('journals.created_on', 'journals.id', 'journal_details.id')
      .pluck('journals.journalized_id', 'journals.id', 'journals.created_on',
             'journal_details.property', 'journal_details.prop_key', 'journal_details.old_value', 'journal_details.value')
      .each do |issue_id, journal_id, created_on, property, key, old_value, value|
        journal = journals[journal_id] ||= begin
          entry = HistoryJournal.new(journal_id, created_on, [])
          result[issue_id] << entry
          entry
        end
        journal.details << HistoryDetail.new(property, key, old_value, value)
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

  def self.calculate(rows, date, start_date)
    open = rows.select { |r| r[:open] }
    not_overdue, overdue = open.partition { |r| r[:due].nil? || r[:due] >= date }
    started, untouched = overdue.partition { |r| r[:started] }
    # Section 2 alone excludes these as-of statuses. Do not filter the input
    # rows globally: Ongoing still belongs to Section 1's open population.
    delivery_rows = rows.reject { |r| DELIVERY_EXCLUDED_STATUSES.include?(r[:status_name].to_s.strip) }
    due = delivery_rows.select { |r| r[:due] && r[:due] <= date }
    done = due.select { |r| r[:done] }
    months = month_fraction(start_date, date)
    delivered = delivery_rows.select { |r| r[:done] && r[:delivered_at] && start_date && r[:delivered_at].between?(start_date, date) }
    # Use current Redmine Start dates and visible positive current weights.
    # Open eligible tickets can establish the start of weight measurement too.
    weight_start = delivery_rows.filter_map { |r| r[:start_date] if r[:weight].positive? && r[:start_date] && r[:start_date] <= date }.min
    weight_months = month_fraction(weight_start, date)
    weighted_delivered = delivery_rows.select do |r|
      r[:weight].positive? && r[:done] && r[:delivered_at] && weight_start && r[:delivered_at].between?(weight_start, date)
    end
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
      monthly_count: months && delivered.size / months,
      count_start_date: start_date, weight_start_date: weight_start,
      monthly_weight: weight_months && weight(weighted_delivered) / weight_months
    }
  end

  def self.weight(rows)
    rows.sum { |row| row[:weight] }
  end

  # Inclusive calendar days, with each partial month divided by its own length.
  def self.month_fraction(first, last)
    return unless first && first <= last
    total = 0.0
    cursor = first
    while cursor <= last
      boundary = [cursor.end_of_month, last].min
      total += ((boundary - cursor).to_i + 1).to_f / cursor.end_of_month.day
      cursor = boundary + 1
    end
    total
  end
end
