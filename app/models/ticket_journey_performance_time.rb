# Live Time: date-only working calendar, current schedule/owner, historical status.
class TicketJourneyPerformanceTime
  COLORS = %w[#00bc87 #008fff #ffad29 #f65362].freeze
  BUCKETS = ['0–15 working days', '16–30 working days', '31–60 working days', '>60 working days'].freeze
  LABELS = {
    'time_open' => 'All Open Tickets — Time', 'time_priority' => 'Priority Open Tickets',
    'time_immediate' => 'Immediate / Hot Fix Open Tickets', 'time_age_excluded' => 'Open Tickets with Missing or Future Start Dates',
    'time_priority_age_excluded' => 'Priority Open Tickets with Missing or Future Start Dates',
    'time_ongoing' => 'Ongoing Open Tickets — Excluded from Aging',
    'time_priority_ongoing' => 'Priority Ongoing Tickets — Excluded from Aging',
    'time_sv' => 'Active Ticket Schedule Variance Contributors', 'time_sv_excluded' => 'Active Tickets Excluded from SV',
    'time_estimate_excluded' => 'Active Tickets Without Usable PM Estimates',
    'time_balance' => 'Estimate Balance Contributors',
    'time_active' => 'Active Open Tickets — Time',
    'time_archived' => 'Archived Tickets — Time',
    'time_delivered' => 'Monthly Productivity Contributors',
    'time_delivered_excluded' => 'Monthly Productivity Data Review'
  }.merge((0..3).to_h { |index| ["time_age_#{index}", BUCKETS[index]] })
   .merge((0..3).to_h { |index| ["time_priority_#{index}", "Priority: #{BUCKETS[index]}"] }).freeze

  def self.positive(value)
    TicketJourney::WorkingCalendar.positive_number(value)
  end

  # One batch-bounded query of visible direct entries. Work date, not record
  # creation date, is authoritative. Entries after as_of and negatives are omitted.
  def self.hours_for(ids, date)
    result = Hash.new { |hash, id| hash[id] = [] }
    TimeEntry.visible(User.current).where(issue_id: ids)
      .where('time_entries.spent_on <= ? AND time_entries.hours >= 0 AND time_entries.hours <= ?', date, Float::MAX)
      .group(:issue_id, :spent_on).sum(:hours).each do |(id, day), hours|
        number = hours.to_f
        result[id] << [day.to_date, number] if number.finite?
      end
    result
  end

  def self.spent(entries, date)
    entries.sum { |day, hours| day <= date ? hours : 0.0 }
  end

  # Bounded to the current issue batch; booked user, never entry creator.
  def self.owner_hours_for(ids, owner_ids, date)
    TimeEntry.visible(User.current).where(issue_id: ids, user_id: owner_ids)
      .where('time_entries.spent_on <= ? AND time_entries.hours >= 0 AND time_entries.hours <= ?', date, Float::MAX)
      .group(:issue_id, :user_id).sum(:hours)
  end

  def self.owner_report(rows, share)
    factor = share / 100.0
    calculate(rows.map do |row|
      row.merge(spent: row[:owner_spent],
        estimate: row[:estimate] && row[:estimate] * factor,
        planned: row[:planned] && row[:planned] * factor)
    end)
  end

  def self.enrich(row, issue, date, calendar, entries, can_view_time, daily_hours)
    start = issue.start_date
    estimate = positive(issue.estimated_hours)
    hours = can_view_time ? spent(entries, date) : nil
    age = TicketJourneyPerformance.aging_eligible?(row[:status_name]) ? calendar.age(start, date) : nil
    fraction = calendar.elapsed_fraction(start, issue.due_date, date, daily_hours: daily_hours)
    reasons = []
    reasons << 'Set Start Date' unless start
    reasons << 'Start Date is after report date' if start && start > date
    reasons << 'Set Due Date' unless issue.due_date
    reasons << 'Due Date must be after Start Date' if start && issue.due_date && issue.due_date <= start
    reasons << 'Schedule contains no working days' if start && issue.due_date && issue.due_date > start && fraction.nil?
    reasons << 'Set a positive finite PM Estimate' unless estimate
    reasons << 'Logged time unavailable under current permissions' unless can_view_time
    row.merge(start_date: start, estimate: estimate, spent: hours, age: age,
      priority: issue.priority&.name.to_s,
      planned: reasons.empty? ? estimate * fraction : nil, exclusions: reasons,
      early_hours: can_view_time && start ? entries.sum { |day, value| day < start && day <= date ? value : 0.0 } : nil)
  end

  def self.priority?(row)
    row[:priority].match?(/urgent|immediate/i)
  end

  def self.bucket(age)
    return if age.nil?
    age <= 15 ? 0 : (age <= 30 ? 1 : (age <= 60 ? 2 : 3))
  end

  def self.calculate(rows, month: nil)
    open = rows.select { |row| row[:open] && !TicketJourneyPerformance::OPEN_EXCLUDED_STATUSES.include?(row[:status_name]) }
    priority = open.select { |row| priority?(row) }
    age_eligible = open.select { |row| TicketJourneyPerformance.aging_eligible?(row[:status_name]) }
    active = age_eligible
    archived = rows.select { |row| row[:status_name].to_s.strip == 'Archived' }
    spent_population = open + archived
    priority_age_eligible = priority.select { |row| TicketJourneyPerformance.aging_eligible?(row[:status_name]) }
    sets = {
      'time_open' => open, 'time_priority' => priority,
      'time_active' => active, 'time_archived' => archived,
      # Hot Fix is the Immediate view, not an invented tracker/custom-field rule.
      'time_immediate' => open.select { |row| row[:priority].match?(/immediate/i) },
      'time_ongoing' => open - age_eligible,
      'time_priority_ongoing' => priority - priority_age_eligible,
      'time_age_excluded' => age_eligible.select { |row| row[:age].nil? },
      'time_priority_age_excluded' => priority_age_eligible.select { |row| row[:age].nil? },
      'time_sv' => active.select { |row| row[:exclusions].empty? },
      'time_sv_excluded' => active.reject { |row| row[:exclusions].empty? },
      'time_estimate_excluded' => active.reject { |row| row[:estimate] },
      'time_balance' => active.select { |row| row[:estimate] && !row[:spent].nil? }
    }
    monthly = month ? rows.select { |row| TicketJourneyPerformance.monthly_delivery?(row, month.beginning_of_month, month) } : []
    sets['time_delivered'] = monthly.select { |row| !row[:missing_weight] && !row[:spent].nil? }
    sets['time_delivered_excluded'] = monthly.reject { |row| !row[:missing_weight] && !row[:spent].nil? }
    if month
      missing_completion = rows.select { |row| TicketJourneyPerformance.delivery_eligible?(row) && row[:done] && !row[:delivered_at] }
      sets['time_delivered_excluded'] += missing_completion
    end
    4.times do |index|
      sets["time_age_#{index}"] = age_eligible.select { |row| bucket(row[:age]) == index }
      sets["time_priority_#{index}"] = priority_age_eligible.select { |row| bucket(row[:age]) == index }
    end
    sv = sets['time_sv']
    planned = sv.sum { |row| row[:planned] }
    actual = sv.sum { |row| row[:spent] }
    balance_rows = sets['time_balance']
    balance_estimate = balance_rows.sum { |row| row[:estimate] }
    balance_spent = balance_rows.sum { |row| row[:spent] }
    estimates = active.filter_map { |row| row[:estimate] }
    hours = spent_population.filter_map { |row| row[:spent] }
    open_hours = open.filter_map { |row| row[:spent] }
    spent_groups = { active_spent: active, ongoing_spent: open - active, archived_spent: archived }.transform_values do |group|
      values = group.filter_map { |row| row[:spent] }
      group.any? && values.empty? ? nil : values.sum
    end
    excluded_estimate_hours = sets['time_estimate_excluded'].filter_map { |row| row[:spent] }
    { sets: sets, open: open.size, priority: priority.size,
      estimate: estimates.empty? ? nil : estimates.sum, spent: hours.empty? ? nil : hours.sum,
      open_spent: open_hours.empty? ? nil : open_hours.sum,
      **spent_groups,
      time_unavailable: spent_population.count { |row| row[:spent].nil? },
      estimate_excluded_spent: excluded_estimate_hours.empty? ? nil : excluded_estimate_hours.sum,
      balance: balance_rows.empty? ? nil : balance_estimate - balance_spent,
      balance_percent: balance_estimate.positive? ? (balance_estimate - balance_spent) * 100 / balance_estimate : nil,
      balance_estimate: balance_estimate, balance_spent: balance_spent,
      planned: planned, actual: actual,
      sv: planned.positive? ? (planned - actual) * 100 / planned : nil,
      early_hours: open.sum { |row| row[:early_hours].to_f } }
  end

  def self.trend_points(date)
    TicketJourneyPerformance.completed_month_ends(date).map do |day|
      { date: day, count: 0, weight: 0.0, hours: 0.0, excluded: 0, missing_completion: 0 }
    end
  end

  def self.add_productivity!(point, row, hours)
    return unless TicketJourneyPerformance.delivery_eligible?(row) && row[:done]
    unless row[:delivered_at]
      point[:missing_completion] += 1
      return
    end
    return unless TicketJourneyPerformance.monthly_delivery?(row, point[:date].beginning_of_month, point[:date])
    if row[:missing_weight] || hours.nil?
      point[:excluded] += 1
    else
      point[:count] += 1
      point[:weight] += row[:weight]
      point[:hours] += hours
    end
  end

  def self.finish_trend!(points)
    points.each { |point| point[:productivity] = point[:hours].positive? ? point[:weight] / point[:hours] : nil }
  end
end
