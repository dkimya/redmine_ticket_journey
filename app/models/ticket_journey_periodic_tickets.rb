# Provisional Periodic Tickets rules. Keep population decisions here, not in views.
# Current owner/due/weight/priority; historical status and recorded event dates.
class TicketJourneyPeriodicTickets
  EXCLUDED_STATUSES = ['Archived', 'Ongoing', 'On-Hold'].freeze
  HOTFIX_PRIORITY = 'Immediate/Hot Fix'.freeze
  LABELS = {
    'beginning' => 'Debt at RSD', 'planned' => 'Planned Assigned Tasks',
    'hotfix' => 'Assigned Hotfixes', 'expected' => 'Expected Total',
    'completed' => 'Completed from Expectation', 'other' => 'Other Done Tickets (Not Expected)',
    'actual' => 'Total Actual Done', 'debt' => 'Debt at RED', 'still_open' => 'Still Open Now',
    'missing_weight' => 'Tickets Without Usable Complexity Weight',
    'missing_assignment' => 'Tickets Without Recorded Assignment to Current Owner by RED',
    'missing_due' => 'Tickets Without Due Dates',
    'missing_completion' => 'Done Tickets Without Recorded Completion Dates',
    'excluded' => 'Tickets Excluded by Status at RED',
    'trend_expected' => 'Cumulative Expected Work', 'trend_completed' => 'Cumulative Completed Expected Work',
    'completed_beginning' => 'Completed Beginning Debt', 'completed_planned' => 'Completed Planned Tasks',
    'completed_hotfix' => 'Completed Assigned Hotfixes'
  }.freeze

  # Status history must include future edits to rewind RED. Owner history is
  # needed only through RED for assignment evidence, independent of attribution.
  def self.history_for(ids, last_day)
    result = Hash.new { |hash, id| hash[id] = [] }
    journals = {}
    JournalDetail.joins(:journal)
      .where(journals: { journalized_type: 'Issue', journalized_id: ids })
      .where("(journal_details.property = ? AND journal_details.prop_key = ?) OR (journal_details.property = ? AND journal_details.prop_key = ? AND journals.created_on <= ?)",
        'attr', 'status_id', 'cf', '57', last_day.in_time_zone.end_of_day)
      .order('journals.created_on', 'journals.id', 'journal_details.id')
      .pluck('journals.journalized_id', 'journals.id', 'journals.created_on', 'journal_details.property',
        'journal_details.prop_key', 'journal_details.old_value', 'journal_details.value', 'journal_details.id')
      .each do |issue_id, journal_id, at, property, key, old_value, value, detail_id|
        journal = journals[journal_id] ||= begin
          entry = TicketJourneyPerformance::HistoryJournal.new(journal_id, at, [])
          result[issue_id] << entry
          entry
        end
        journal.details << TicketJourneyPerformance::HistoryDetail.new(property, key, old_value, value, detail_id)
      end
    result
  end

  def self.assignment_date(history, owner_id, last_day)
    history.select { |entry| entry.created_on <= last_day.in_time_zone.end_of_day }
      .select do |entry|
        entry.details.any? do |detail|
          detail.property == 'cf' && detail.prop_key == '57' &&
            detail.value.to_s == owner_id && detail.old_value.to_s != owner_id
        end
      end.max_by { |entry| [entry.created_on, entry.id] }&.created_on&.in_time_zone&.to_date
  end

  def self.row(issue, first_day, last_day, statuses, history, values, owner_id)
    ending = TicketJourneyPerformance.snapshot(issue, last_day, statuses,
      history: history, visible_values: values, owner_value: owner_id)
    return unless ending

    beginning = TicketJourneyPerformance.snapshot(issue, first_day - 1, statuses,
      history: history, visible_values: values, owner_value: owner_id)
    ending.merge(
      beginning_open: beginning && beginning[:open] && !EXCLUDED_STATUSES.include?(beginning[:status_name]),
      closed_before: beginning && !beginning[:open],
      assigned_on: assignment_date(history, owner_id, last_day),
      hotfix: issue.priority&.name.to_s.strip == HOTFIX_PRIORITY,
      current_open: statuses[issue.status_id.to_s] && !statuses[issue.status_id.to_s].is_closed,
      project_id: issue.project_id, project_name: issue.project.name,
      tracker_name: issue.tracker.name, subject: issue.subject
    )
  end

  def self.category(row, first_day, last_day)
    return 'beginning' if row[:beginning_open] && row[:due] && row[:due] < first_day
    return if row[:closed_before]
    return 'hotfix' if row[:hotfix] && row[:assigned_on]&.between?(first_day, last_day)
    return 'planned' if row[:due]&.between?(first_day, last_day)
  end

  def self.expected_date(row, first_day, last_day)
    return first_day if row[:category] == 'beginning'
    # A hotfix assigned within the period is expected in this period even when
    # its current due date is absent/outside it. Use recorded assignment then.
    due = row[:due]
    due&.between?(first_day, last_day) ? due : row[:assigned_on]
  end

  def self.calculate(rows, first_day, last_day)
    rows = rows.uniq { |row| row[:id] }
    excluded, eligible = rows.partition { |row| EXCLUDED_STATUSES.include?(row[:status_name]) }
    eligible = eligible.map do |row|
      item = row.merge(category: category(row, first_day, last_day))
      item.merge(expected_on: item[:category] ? expected_date(item, first_day, last_day) : nil)
    end
    expected, outside = eligible.partition { |row| row[:category] }
    delivered = lambda { |row| row[:done] && row[:delivered_at]&.between?(first_day, last_day) }
    completed, debt = expected.partition(&delivered)
    other = outside.select(&delivered)
    relevant = (expected + completed + other).uniq { |row| row[:id] }
    sets = {
      'beginning' => expected.select { |row| row[:category] == 'beginning' },
      'planned' => expected.select { |row| row[:category] == 'planned' },
      'hotfix' => expected.select { |row| row[:category] == 'hotfix' },
      'expected' => expected, 'completed' => completed, 'other' => other,
      'actual' => completed + other, 'debt' => debt,
      'still_open' => debt.select { |row| row[:current_open] },
      'missing_weight' => relevant.select { |row| row[:missing_weight] },
      'missing_assignment' => eligible.select { |row| row[:assigned_on].nil? },
      'missing_due' => eligible.select { |row| row[:due].nil? },
      'missing_completion' => eligible.select { |row| row[:done] && row[:delivered_at].nil? },
      'excluded' => excluded
    }
    %w[beginning planned hotfix].each do |key|
      sets["completed_#{key}"] = completed.select { |row| row[:category] == key }
    end
    { sets: sets, summaries: sets.transform_values { |items| summary(items) },
      trends: trend_dates(first_day, last_day).map { |day| trend_point(sets, day) } }
  end

  def self.summary(rows)
    { count: rows.size, weight: TicketJourneyPerformance.weight(rows),
      missing_weight: rows.count { |row| row[:missing_weight] } }
  end

  def self.deviation(plan, actual, direction = :actual_minus_plan)
    value = direction == :plan_minus_actual ? plan - actual : actual - plan
    { value: value, percent: plan.positive? ? value * 100.0 / plan : nil }
  end

  def self.metric_rows(report, measure)
    sets = report[:sets]
    amount = ->(items) { measure == :count ? items.size : TicketJourneyPerformance.weight(items) }
    rows = %w[beginning planned hotfix].map do |key|
      actual = key == 'beginning' ? amount.call(sets[key]) : amount.call(sets["completed_#{key}"])
      plan = key == 'beginning' ? 0 : amount.call(sets[key])
      [key, plan, actual, key == 'beginning' ? :plan_minus_actual : :actual_minus_plan]
    end
    rows += [['expected', amount.call(sets['expected']), amount.call(sets['completed']), :actual_minus_plan],
      ['other', 0, amount.call(sets['other']), :plan_minus_actual],
      ['actual', amount.call(sets['expected']), amount.call(sets['actual']), :actual_minus_plan],
      ['debt', 0, amount.call(sets['debt']), :plan_minus_actual],
      ['still_open', 0, amount.call(sets['still_open']), :plan_minus_actual]]
    rows.map do |key, plan, actual, direction|
      { key: key, plan: plan, actual: actual, deviation: deviation(plan, actual, direction), direction: direction }
    end
  end

  # Monday-based weeks, with opening and partial first/last points. For long
  # periods use month ends to bound graph size; exact daily event dates still apply.
  def self.trend_dates(first_day, last_day)
    dates = [first_day - 1]
    if (last_day - first_day).to_i > 120
      day = first_day.end_of_month
      while day < last_day
        dates << day
        day = (day + 1).end_of_month
      end
    else
      day = first_day + (7 - first_day.cwday)
      while day < last_day
        dates << day
        day += 7
      end
    end
    (dates + [last_day]).uniq
  end

  def self.trend_point(sets, day)
    expected = trend_rows(sets, 'expected', day)
    completed = trend_rows(sets, 'completed', day)
    { date: day, expected_count: expected.size, completed_count: completed.size,
      expected_weight: TicketJourneyPerformance.weight(expected), completed_weight: TicketJourneyPerformance.weight(completed) }
  end

  def self.trend_rows(sets, kind, day)
    if kind == 'expected'
      sets['expected'].select { |row| row[:expected_on] <= day || (row[:category] == 'beginning' && row[:expected_on] == day + 1) }
    else
      sets['completed'].select { |row| row[:delivered_at] <= day }
    end
  end
end
