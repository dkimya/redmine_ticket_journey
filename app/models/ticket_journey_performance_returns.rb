# Performance Returns uses dated journal events, never the native lifetime cache.
# Consecutive repeats are a separate accumulated measure, not a resettable streak.
class TicketJourneyPerformanceReturns
  # Open population matches Tickets; the metric denominator is returned tickets.
  EXCLUDED = TicketJourneyPerformance::OPEN_EXCLUDED_STATUSES
  LABELS = {
    'returns_open' => 'All Open Tickets — Returns',
    'returns_0' => '0 Return', 'returns_1' => '1 Return', 'returns_2' => '2 Returns',
    'returns_3' => '3 Returns', 'returns_4' => '3+ Returns (4 or more)',
    'repeats_all' => 'Tickets with Consecutive Returns',
    'repeats_1' => '1 Consecutive Return', 'repeats_2' => '2 Consecutive Returns',
    'repeats_3' => '2+ Consecutive Returns (3 or more)',
    'return_incidents' => 'Open Tickets with at Least One Return — Metric Contributors',
    'non_merge_incidents' => 'Non-Merge Return Incidents — Contributors',
    'non_merge_denominator' => 'Returned Tickets — Non-Merge Metric Denominator',
    'unknown_return_reasons' => 'Returned Tickets with Unavailable Incident Reasons'
  }.freeze
  COLORS = ['#00bc87', '#008fff', '#ffbd36', '#ff8b2d', '#f65362'].freeze
  RETURN_TYPES = {
    C1: ['R1', 'Feedback → Returned'], C2: ['R2', 'Review → Returned'],
    C3: ['R3', 'Ready to Merge → Returned'], C4: ['R4', 'Final Check → Returned'],
    C5: ['R5', 'Done / Closed → Returned']
  }.freeze

  def self.return_types(report)
    counts = RETURN_TYPES.keys.to_h { |key| [key, 0] }
    reasons = Hash.new(0)
    report[:sets].fetch('returns_open').each do |row|
      row[:events].each do |event|
        counts[event[:counter_key]] += 1 if counts.key?(event[:counter_key])
        reasons[event[:reason].to_s.strip.presence || 'Reason unavailable'] += 1
      end
    end
    maximum = reasons.values.max
    {
      stages: counts,
      rate: report[:open].positive? ? 100.0 * report[:returned] / report[:open] : nil,
      top_reasons: reasons.select { |_reason, count| count == maximum }.sort_by { |reason, _count| reason.downcase }
    }
  end

  def self.trend_points(date)
    TicketJourneyPerformance.completed_month_ends(date).map do |day|
      { date: day,
        open: 0, returned: 0, incidents: 0, non_merge: 0, unknown: 0 }
    end
  end

  # Reuse each candidate's loaded scalar history. Retain only monthly aggregates,
  # including tickets closed or reassigned by the main report date.
  def self.accumulate_trend!(points, issue, history, statuses, date, visible_values, owner_ids, owner_points: nil)
    owner_value = visible_values.find { |value| value.custom_field.id == 57 }&.value.to_s
    snapshots = points.map do |point|
      row = TicketJourneyPerformance.snapshot(issue, point[:date], statuses,
        history: history, visible_values: visible_values, owner_value: owner_value)
      row if row && owner_ids.include?(row[:owner_id]) && eligible?(row)
    end
    return unless snapshots.any?

    reason = visible_values.find { |value| value.custom_field.id == 66 }
    events = events_for(issue, history, statuses, date, reason_value: reason&.value, reason_visible: !reason.nil?)
    points.each_with_index do |point, index|
      next unless snapshots[index]

      cutoff = point[:date].in_time_zone.end_of_day
      destinations = [point]
      destinations << owner_points.fetch(snapshots[index][:owner_id])[index] if owner_points
      destinations.each do |destination|
        destination[:open] += 1
        destination[:returned] += 1 if events.any? { |event| event[:at] <= cutoff }
        events.each do |event|
          next if event[:at] > cutoff

          destination[:incidents] += 1
          destination[:non_merge] += 1 if event[:merge_conflict] == false
          destination[:unknown] += 1 if event[:merge_conflict].nil?
        end
      end
    end
    events
  end

  def self.finish_trend!(points)
    points.each do |point|
      point[:ratio] = point[:returned].positive? ? point[:incidents].to_f / point[:returned] : nil
      point[:adjusted_ratio] = point[:returned].positive? && point[:unknown].zero? ? point[:non_merge].to_f / point[:returned] : nil
    end
  end

  def self.eligible?(row)
    row[:open] && !EXCLUDED.include?(row[:status_name].to_s.strip)
  end

  def self.events_for(issue, history, statuses, date, reason_value:, reason_visible:)
    family = TicketJourneyController::TRACKER_FAMILY_DEFINITIONS.find do |_key, definition|
      definition[:tracker_names].include?(issue.tracker.name)
    end&.first || :internal
    cutoff = date.in_time_zone.end_of_day
    reason = reason_value
    transitions = []
    # At a journal timestamp the reason is its post-edit value (also when the
    # status and reason changed together). Undo it only after recording events.
    history.sort_by { |entry| [entry.created_on, entry.id] }.reverse_each do |journal|
      if journal.created_on <= cutoff
        journal.details.each do |detail|
          next unless detail.property == 'attr' && detail.prop_key == 'status_id'
          transitions << {
            journal_detail_id: detail.id, journal_id: journal.id, at: journal.created_on,
            from_status: statuses[detail.old_value.to_s]&.name.to_s.strip,
            to_status: statuses[detail.value.to_s]&.name.to_s.strip,
            reason: reason_visible ? reason.to_s.presence : nil
          }
        end
      end
      journal.details.reverse_each do |detail|
        reason = detail.old_value if detail.property == 'cf' && detail.prop_key == '66'
      end
    end
    events = TicketJourney::ReturnCount.events(family, transitions.sort_by { |event| [event[:at], event[:journal_id], event[:journal_detail_id] || 0] })
    previous = nil
    events.each do |event|
      event[:repeat] = event[:counter_key] == previous
      previous = event[:counter_key]
      event[:merge_conflict] = event[:reason] ? !!event[:reason].match(/\bmerge(?:[\s\/_-]+integration)?[\s\/_-]*conflicts?\b/i) : nil
    end
    events
  end

  def self.calculate(rows)
    summarize(rows.select { |row| eligible?(row) })
  end

  # Shared distributions for Live open tickets and Periodic completed cohorts.
  # Caller owns population selection; return event/repeat definitions stay shared.
  def self.summarize(open)
    open = open.uniq { |row| row[:id] }
    sets = { 'returns_open' => open }
    0.upto(4) { |i| sets["returns_#{i}"] = open.select { |row| [row[:return_count], 4].min == i } }
    sets['repeats_all'] = open.select { |row| row[:repeat_count].positive? }
    1.upto(3) { |i| sets["repeats_#{i}"] = open.select { |row| [row[:repeat_count], 3].min == i } }
    sets['return_incidents'] = open.select { |row| row[:return_count].positive? }
    sets['non_merge_incidents'] = open.select { |row| row[:events].any? { |event| event[:merge_conflict] == false } }
    sets['non_merge_denominator'] = sets['return_incidents']
    sets['unknown_return_reasons'] = open.select { |row| row[:events].any? { |event| event[:merge_conflict].nil? } }
    incidents = open.sum { |row| row[:return_count] }
    unknown = open.sum { |row| row[:events].count { |event| event[:merge_conflict].nil? } }
    non_merge = open.sum { |row| row[:events].count { |event| event[:merge_conflict] == false } }
    {
      open: open.size, population: open.size, returned: sets['return_incidents'].size,
      incidents: incidents, repeats: open.sum { |row| row[:repeat_count] },
      with_repeats: sets['repeats_all'].size, non_merge: non_merge, unknown: unknown, sets: sets,
      ratio: sets['return_incidents'].any? ? incidents.to_f / sets['return_incidents'].size : nil,
      adjusted_ratio: sets['return_incidents'].any? && unknown.zero? ? non_merge.to_f / sets['return_incidents'].size : nil
    }
  end
end
