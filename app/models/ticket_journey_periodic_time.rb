# Periodic Time: ticket attribution is current owner; personal time
# always follows TimeEntry.user_id. All loaders are read-only and batch bounded.
class TicketJourneyPeriodicTime
  WORK_CATEGORIES = %w[expected_done expected_unfinished other archived ongoing excluded unclassified].freeze
  GROUP_FIELDS = { 'actor' => :report_owner_name, 'project' => :project_name,
    'tracker' => :tracker_name, 'status' => :status_name }.freeze

  def self.group_value(row, key)
    GROUP_FIELDS.key?(key) ? row[GROUP_FIELDS[key]].to_s : ''
  end

  METRICS = {
    'dtc' => ['Average Days to Close', 'days', :plan_minus_actual],
    'priority_dtc' => ['Priority Average Days to Close', 'days', :plan_minus_actual],
    'ticket_cost' => ['Ticket Cost — PM vs Actual', 'h', :plan_minus_actual],
    'expected_done_hours' => ['Owner Logged Time — Expected Done (comparable)', 'h', :plan_minus_actual],
    'other_hours' => ['Owner Logged Time — Other Tickets', 'h', :plan_minus_actual],
    'total_hours' => ['Visible Scoped Owner Logged Time', 'h', :actual_minus_plan],
    'daily_hours' => ['Average Logged Time per Owner-Workday', 'h/day', :actual_minus_plan],
    'efficiency' => ['Delivered Expected Complexity Weight / Owner Hour', 'CW/h', :actual_minus_plan]
  }.freeze
  LABELS = METRICS.transform_values(&:first).merge(
    'expected_done_all' => 'All Owner Hours on Completed Expected Work',
    'expected_work_hours' => 'Logged Hours on the Full Expectation Package',
    'expected_unfinished' => 'Owner Hours on Unfinished Expected Work',
    'unclassified' => 'Owner Hours with Unavailable Ticket Owner',
    'archived_hours' => 'Logged Hours on Currently Archived Tickets',
    'ongoing_hours' => 'Logged Hours on Current Ongoing Tickets',
    'excluded_hours' => 'Logged Hours on Current On-Hold Tickets',
    'time_mix' => 'Logged Time by Activity and User',
    'ownership_review' => 'Logged Time on Tickets with Recorded Owner Changes',
    'cost_excluded' => 'Done Tickets Excluded from Cost Comparison',
    'expected_done_excluded' => 'Completed Expected Tickets Excluded from Owner-Hours Comparison',
    'efficiency_excluded' => 'Expected Tickets Excluded from Efficiency Comparison',
    'dtc_excluded' => 'Done Tickets Without Usable Creation/Completion Dates'
  ).freeze

  def self.load_hours(ids, first_day, last_day, owners)
    visible = TimeEntry.visible(User.current).where(issue_id: ids).where('time_entries.spent_on <= ?', last_day)
    valid = visible.where('time_entries.hours >= 0 AND time_entries.hours <= ?', Float::MAX)
    costs = valid.group(:issue_id).sum(:hours).transform_values { |value| finite_sum(value) }
    logs = Hash.new { |hash, id| hash[id] = Hash.new { |by_user, user| by_user[user] = [] } }
    valid.where(user_id: owners, spent_on: first_day..last_day).group(:issue_id, :user_id, :spent_on).sum(:hours)
      .each do |(id, user, day), hours|
        logs[id][user.to_s] << [day.to_date, finite_sum(hours)]
      end
    invalid = visible.where('time_entries.hours < 0 OR time_entries.hours > ? OR time_entries.hours IS NULL', Float::MAX)
    mix = Hash.new { |hash, id| hash[id] = [] }
    valid.where(spent_on: first_day..last_day).group(:issue_id, :user_id, :activity_id, :spent_on).sum(:hours).each do |(id, user, activity, day), hours|
      mix[id] << { user_id: user.to_s, activity_id: activity.to_s, day: day.to_date, hours: finite_sum(hours) }
    end
    invalid.where(spent_on: first_day..last_day).group(:issue_id, :user_id, :activity_id, :spent_on).count.each do |(id, user, activity, day), count|
      mix[id] << { user_id: user.to_s, activity_id: activity.to_s, day: day.to_date, hours: nil, invalid_count: count }
    end
    { costs: costs, logs: logs, invalid_costs: invalid.group(:issue_id).count,
      mix: mix,
      invalid_logs: invalid.where(user_id: owners, spent_on: first_day..last_day).group(:issue_id, :user_id, :spent_on).count }
  end

  def self.finite_sum(value)
    number = value.to_f
    number if number.finite? && number >= 0
  end

  def self.enrich(row, issue, hours, time_allowed, owner_visible)
    cost = time_allowed ? hours[:costs].fetch(issue.id, 0.0) : nil
    cost = nil if hours[:invalid_costs].fetch(issue.id, 0).positive?
    logs = hours[:logs].fetch(issue.id, {})
    invalid_users = hours[:invalid_logs].select { |(id, _user, _day), _count| id == issue.id }.to_h
    row.merge(created_date: issue.created_on.in_time_zone.to_date,
      estimate: TicketJourney::WorkingCalendar.positive_number(issue.estimated_hours),
      priority: issue.priority&.name.to_s, ticket_hours: cost, time_allowed: time_allowed,
      owner_visible: owner_visible, owner_logs: time_allowed ? logs : {}, invalid_logs: invalid_users,
      mix_records: time_allowed ? hours.fetch(:mix, {}).fetch(issue.id, []) : [],
      invalid_costs: hours[:invalid_costs].fetch(issue.id, 0))
  end

  def self.personal_hours(row, owner_id, first_day, last_day)
    return nil unless row[:time_allowed]
    return nil if invalid_count(row, owner_id, first_day, last_day).positive?
    entries = row.fetch(:owner_logs, {}).fetch(owner_id, []).select { |day, _hours| day.between?(first_day, last_day) }
    return nil if entries.any? { |_day, hours| hours.nil? }
    finite_sum(entries.sum { |_day, hours| hours })
  end

  def self.invalid_count(row, owner_id, first_day, last_day)
    row.fetch(:invalid_logs, {}).sum do |(id, user, day), count|
      id == row[:id] && user.to_s == owner_id && day.to_date.between?(first_day, last_day) ? count : 0
    end
  end

  def self.metric(plan, actual, direction, rows, **extra)
    plan = finite_sum(plan) unless plan.nil?
    actual = finite_sum(actual) unless actual.nil?
    delta = plan.nil? || actual.nil? ? nil : TicketJourneyPeriodicTickets.deviation(plan, actual, direction)
    { plan: plan, actual: actual, deviation: delta, rows: rows }.merge(extra)
  end

  def self.mean(values)
    values.empty? ? nil : values.sum.to_f / values.size
  end

  def self.work_category(row, expected_ids, completed_ids)
    return 'archived' if TicketJourneyPeriodicTickets.current_status(row) == 'Archived'
    return 'ongoing' if TicketJourneyPeriodicTickets.current_status(row) == 'Ongoing'
    return 'excluded' if TicketJourneyPeriodicTickets.excluded?(row)
    return 'unclassified' unless row[:owner_visible]
    return 'expected_done' if completed_ids.include?(row[:id])
    expected_ids.include?(row[:id]) ? 'expected_unfinished' : 'other'
  end

  def self.reconciliation(breakdown)
    parts = %w[expected_done expected_unfinished].map { |key| breakdown[key] }
    breakdown.except('expected_done', 'expected_unfinished').merge(
      'expected_work' => parts.any?(&:nil?) ? nil : finite_sum(parts.sum))
  end

  def self.owner_report(rows, owner_id, first_day, last_day, calendar, settings, daily_hours,
    total_available:, any_time_available: true, package: nil, completion_range: nil, comparison_range: nil)
    comparison_first, comparison_last = comparison_range || [first_day, last_day]
    own = rows.select { |row| row[:owner_visible] && row[:owner_id] == owner_id }
    tickets = package || TicketJourneyPeriodicTickets.calculate(own, first_day, last_day, with_trends: false)
    done = tickets[:sets]['actual']
    done = done.select { |row| row[:delivered_at].between?(*completion_range) } if completion_range
    expected = tickets[:sets]['expected']
    expected_ids = expected.map { |row| row[:id] }.to_set
    completed_ids = tickets[:sets]['completed'].map { |row| row[:id] }.to_set
    # Personal time belongs to the logged user, not the entry creator or ticket owner.
    personal = rows.filter_map do |row|
      entries = row.fetch(:owner_logs, {}).fetch(owner_id, []).select { |day, _hours| day.between?(first_day, last_day) }
      next if entries.empty? && invalid_count(row, owner_id, first_day, last_day).zero?
      category = work_category(row, expected_ids, completed_ids)
      row.merge(log_owner_id: owner_id, personal_hours: personal_hours(row, owner_id, first_day, last_day), time_category: category)
    end
    logs = personal.group_by { |row| row[:time_category] }
    sum_logs = lambda do |items|
      items.any? { |row| row[:personal_hours].nil? } ? nil : finite_sum(items.sum { |row| row[:personal_hours] })
    end
    days = calendar.days(first_day, last_day)
    capacity = days.positive? ? days * daily_hours : nil
    share = TicketJourney::PerformanceSettings.periodic_target(settings, 'performance_periodic_owner_share')
    cost_rows = done.select { |row| row[:estimate] && !row[:ticket_hours].nil? }
    cost_plan = cost_rows.sum { |row| row[:estimate] }
    cost_actual = cost_rows.sum { |row| row[:ticket_hours] }
    cost_plan = cost_actual = nil if done.any? && cost_rows.empty?
    expected_done = tickets[:sets]['completed'].select { |row| row[:estimate] && !personal_hours(row, owner_id, comparison_first, comparison_last).nil? }
    expected_done = expected_done.map { |row| row.merge(comparison_owner_hours: personal_hours(row, owner_id, first_day, last_day)) }
    expected_plan = share.nil? ? nil : expected_done.sum { |row| row[:estimate] } * share / 100.0
    expected_actual = expected_done.sum { |row| personal_hours(row, owner_id, first_day, last_day) }
    expected_plan = expected_actual = nil if tickets[:sets]['completed'].any? && expected_done.empty?
    dtc_rows = done.select { |row| row[:created_date] && row[:delivered_at] && row[:delivered_at] >= row[:created_date] }
    durations = dtc_rows.map { |row| (row[:delivered_at] - row[:created_date]).to_f }
    priority_rows = dtc_rows.select { |row| TicketJourneyPerformanceTime.priority?(row) }
    priority_durations = priority_rows.map { |row| (row[:delivered_at] - row[:created_date]).to_f }
    efficiency_rows = expected.select do |row|
      !row[:missing_weight] && row[:estimate] && !personal_hours(row, owner_id, comparison_first, comparison_last).nil?
    end
    expected_weight = TicketJourneyPerformance.weight(efficiency_rows)
    delivered_weight = TicketJourneyPerformance.weight(efficiency_rows.select do |row|
      completed_ids.include?(row[:id]) && (!completion_range || row[:delivered_at].between?(*completion_range))
    end)
    planned_effort = share.nil? ? nil : finite_sum(efficiency_rows.sum { |row| row[:estimate] } * share / 100.0)
    actual_effort = finite_sum(efficiency_rows.sum { |row| personal_hours(row, owner_id, first_day, last_day) })
    cw_plan = planned_effort && planned_effort.positive? ? expected_weight / planned_effort : nil
    cw_actual = actual_effort && actual_effort.positive? ? delivered_weight.to_f / actual_effort : nil
    total_actual = total_available ? sum_logs.call(personal) : nil
    other_rows = logs.fetch('other', [])
    other_actual = total_available ? sum_logs.call(other_rows) : nil
    extra_work = expected.any? && tickets[:sets]['debt'].empty? && completed_ids.size == expected_ids.size
    result = {
      'dtc' => metric(TicketJourney::PerformanceSettings.periodic_target(settings, 'performance_periodic_dtc_target'), mean(durations), :plan_minus_actual, dtc_rows),
      'priority_dtc' => metric(TicketJourney::PerformanceSettings.periodic_target(settings, 'performance_periodic_priority_dtc_target'), mean(priority_durations), :plan_minus_actual, priority_rows),
      'ticket_cost' => metric(cost_plan, cost_actual, :plan_minus_actual, cost_rows),
      'expected_done_hours' => metric(expected_plan, expected_actual, :plan_minus_actual, expected_done),
      'other_hours' => metric(0, other_actual, :plan_minus_actual, other_rows,
        extra_hours: extra_work ? other_actual : 0.0, unplanned_hours: extra_work ? 0.0 : other_actual),
      'total_hours' => metric(capacity, total_actual, :actual_minus_plan, personal),
      'daily_hours' => metric(days.positive? ? daily_hours : nil, total_actual && days.positive? ? total_actual.to_f / days : nil, :actual_minus_plan, personal),
      'efficiency' => metric(cw_plan, cw_actual, :actual_minus_plan, efficiency_rows,
        expected_weight: expected_weight, delivered_weight: delivered_weight, planned_effort: planned_effort, actual_effort: actual_effort)
    }
    sets = result.transform_values { |entry| entry[:rows] }.merge(
      'expected_done_all' => logs.fetch('expected_done', []),
      'expected_work_hours' => logs.fetch('expected_done', []) + logs.fetch('expected_unfinished', []),
      'expected_unfinished' => logs.fetch('expected_unfinished', []), 'unclassified' => logs.fetch('unclassified', []),
      'archived_hours' => logs.fetch('archived', []), 'excluded_hours' => logs.fetch('excluded', []),
      'ongoing_hours' => logs.fetch('ongoing', []),
      'time_mix' => personal,
      'ownership_review' => personal.select { |row| Array(row[:extraordinary_reasons]).include?('Ticket Owner changed') },
      'cost_excluded' => done - cost_rows, 'efficiency_excluded' => expected - efficiency_rows,
      'expected_done_excluded' => tickets[:sets]['completed'].reject { |row| expected_done.any? { |item| item[:id] == row[:id] } },
      'dtc_excluded' => done - dtc_rows)
    breakdown = WORK_CATEGORIES.to_h { |key| [key, any_time_available ? sum_logs.call(logs.fetch(key, [])) : nil] }
    { metrics: result, sets: sets, tickets: tickets, personal: personal,
      breakdown: breakdown, reconciliation: reconciliation(breakdown),
      durations: durations, priority_durations: priority_durations, days: days, capacity: capacity,
      done_count: done.size, expected_done_count: tickets[:sets]['completed'].size,
      valid_visible_hours: any_time_available ? sum_logs.call(personal) : nil,
      expected_done_raw_hours: any_time_available ? sum_logs.call(logs.fetch('expected_done', [])) : nil,
      all_done_visible_cost: done.any? { |row| row[:ticket_hours].nil? } ? nil : finite_sum(done.sum { |row| row[:ticket_hours] }),
      invalid_rows: personal.count { |row| row[:personal_hours].nil? }, available: total_available }
  end

  def self.aggregate(reports, settings)
    metrics = METRICS.keys.to_h do |key|
      values = reports.map { |report| report[:metrics][key] }
      sum = ->(field) { values.any? { |value| value[field].nil? } ? nil : finite_sum(values.sum { |value| value[field] }) }
      plan, actual = sum.call(:plan), sum.call(:actual)
      if %w[dtc priority_dtc].include?(key)
        plan = values.first&.fetch(:plan)
        actual = mean(reports.flat_map { |report| report[key == 'dtc' ? :durations : :priority_durations] })
      elsif key == 'ticket_cost'
        pairs = values.flat_map { |value| value[:rows] }
        plan = pairs.sum { |row| row[:estimate] }
        actual = pairs.sum { |row| row[:ticket_hours] }
        plan = actual = nil if pairs.empty? && reports.sum { |report| report[:done_count] }.positive?
      elsif key == 'expected_done_hours'
        pairs = values.flat_map { |value| value[:rows] }
        share = TicketJourney::PerformanceSettings.periodic_target(settings, 'performance_periodic_owner_share')
        plan = share.nil? ? nil : pairs.sum { |row| row[:estimate] } * share / 100.0
        actual = pairs.sum { |row| row[:comparison_owner_hours] }
        plan = actual = nil if pairs.empty? && reports.sum { |report| report[:expected_done_count] }.positive?
      elsif key == 'daily_hours'
        days = reports.sum { |report| report[:days] }
        capacity = reports.any? { |report| report[:capacity].nil? } ? nil : reports.sum { |report| report[:capacity] }
        hours = reports.map { |report| report[:metrics]['total_hours'][:actual] }
        plan = days.positive? && capacity ? capacity.to_f / days : nil
        actual = days.positive? && hours.none?(&:nil?) ? hours.sum.to_f / days : nil
      elsif key == 'efficiency'
        effort = sum.call(:planned_effort)
        actual_effort = sum.call(:actual_effort)
        plan = effort && effort.positive? ? sum.call(:expected_weight) / effort : nil
        actual = actual_effort && actual_effort.positive? ? sum.call(:delivered_weight).to_f / actual_effort : nil
      end
      entry = metric(plan, actual, METRICS[key][2], values.flat_map { |value| value[:rows] })
      if key == 'efficiency'
        %i[expected_weight delivered_weight planned_effort actual_effort].each { |field| entry[field] = sum.call(field) }
      end
      if key == 'other_hours'
        entry[:extra_hours] = sum.call(:extra_hours)
        entry[:unplanned_hours] = sum.call(:unplanned_hours)
      end
      [key, entry]
    end
    breakdown = WORK_CATEGORIES.to_h do |key|
      values = reports.map { |report| report[:breakdown][key] }
      [key, values.any?(&:nil?) ? nil : values.sum]
    end
    { metrics: metrics, sets: LABELS.keys.to_h { |key| [key, reports.flat_map { |report| report[:sets].fetch(key) }] },
      breakdown: breakdown, reconciliation: reconciliation(breakdown),
      valid_visible_hours: reports.any? { |report| report[:valid_visible_hours].nil? } ? nil : reports.sum { |report| report[:valid_visible_hours] },
      expected_done_raw_hours: reports.any? { |report| report[:expected_done_raw_hours].nil? } ? nil : reports.sum { |report| report[:expected_done_raw_hours] },
      all_done_visible_cost: reports.any? { |report| report[:all_done_visible_cost].nil? } ? nil : reports.sum { |report| report[:all_done_visible_cost] },
      invalid_rows: reports.sum { |report| report[:invalid_rows] }, available: reports.all? { |report| report[:available] } }
  end
end
