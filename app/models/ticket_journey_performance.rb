# Calculation rules for Performance Section 1. No writes or stored counters.
class TicketJourneyPerformance
  TRACKERS = ['Bug', 'Change Request / Improvement', 'Feature', 'Task (Business Jobs)'].freeze
  STARTED = ['In Progress', 'Inprogress', 'Feedback', 'Returned', 'Review', 'Ready to Merge', 'Final Check', 'Done / Closed'].freeze

  def self.snapshot(issue, date, statuses)
    cutoff = date.in_time_zone.end_of_day
    return if issue.created_on > cutoff

    status_id = issue.status_id.to_s
    owner_id = issue.custom_value_for(57)&.value.to_s
    changes = issue.journals.sort_by { |j| [j.created_on, j.id] }
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
    weight_value = issue.visible_custom_field_values.find { |v| v.custom_field.id == 70 }&.value
    weight = weight_value.to_s.tr(',', '.').to_f
    valid_weight = weight.finite? && weight.positive?
    {
      id: issue.id, owner_id: owner_id, due: issue.due_date,
      open: status && !status.is_closed, done: status&.name.to_s.strip == 'Done / Closed',
      started: started, delivered_at: delivered_at,
      weight: valid_weight ? weight : 0.0, missing_weight: !valid_weight
    }
  end

  def self.calculate(rows, date, start_date)
    open = rows.select { |r| r[:open] }
    not_overdue, overdue = open.partition { |r| r[:due].nil? || r[:due] >= date }
    started, untouched = overdue.partition { |r| r[:started] }
    due = rows.select { |r| r[:due] && r[:due] <= date }
    done = due.select { |r| r[:done] }
    months = month_fraction(start_date, date)
    delivered = rows.select { |r| r[:done] && r[:delivered_at] && start_date && r[:delivered_at].between?(start_date, date) }
    {
      groups: [open, not_overdue, started, untouched], due: due, done: done,
      due_soon: not_overdue.count { |r| r[:due] && (r[:due] - date).to_i < 3 },
      missing_due: open.count { |r| r[:due].nil? }, missing_weight: rows.count { |r| r[:missing_weight] },
      missing_delivery: rows.count { |r| r[:done] && r[:delivered_at].nil? },
      monthly_count: months && delivered.size / months,
      monthly_weight: months && weight(delivered) / months
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
