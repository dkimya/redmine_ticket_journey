# Calculation rules for Performance Section 1. No writes or stored counters.
class TicketJourneyPerformance
  BATCH_SIZE = 100
  HistoryDetail = Struct.new(:property, :prop_key, :old_value, :value)
  HistoryJournal = Struct.new(:id, :created_on, :details)
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
  def self.history_for(issue_ids, date)
    result = Hash.new { |hash, id| hash[id] = [] }
    journals = {}
    JournalDetail.joins(:journal)
      .where(journals: { journalized_type: 'Issue', journalized_id: issue_ids })
      .where("(journal_details.property = ? AND journal_details.prop_key = ?) OR (journal_details.property = ? AND journal_details.prop_key = ? AND journals.created_on > ?)",
             'attr', 'status_id', 'cf', '57', date.in_time_zone.end_of_day)
      .order('journals.created_on', 'journals.id', 'journal_details.id')
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

  def self.snapshot(issue, date, statuses, history: nil, visible_values: nil)
    cutoff = date.in_time_zone.end_of_day
    return if issue.created_on > cutoff

    status_id = issue.status_id.to_s
    owner_id = issue.custom_value_for(57)&.value.to_s
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
