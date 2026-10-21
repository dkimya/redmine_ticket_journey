# Performance Returns uses dated journal events, never the native lifetime cache.
# Consecutive repeats are a separate accumulated measure, not a resettable streak.
class TicketJourneyPerformanceReturns
  # Hadi confirmed that Tickets and Returns must share the open denominator.
  EXCLUDED = TicketJourneyPerformance::OPEN_EXCLUDED_STATUSES
  LABELS = {
    'returns_open' => 'All Open Tickets — Returns',
    'returns_0' => '0 Return', 'returns_1' => '1 Return', 'returns_2' => '2 Returns',
    'returns_3' => '3 Returns', 'returns_4' => '3+ Returns (4 or more)',
    'repeats_all' => 'Tickets with Consecutive Returns',
    'repeats_1' => '1 Consecutive Return', 'repeats_2' => '2 Consecutive Returns',
    'repeats_3' => '2+ Consecutive Returns (3 or more)',
    'return_incidents' => 'Return Incidents per Open Ticket — Contributors',
    'non_merge_incidents' => 'Non-Merge Return Incidents — Contributors'
  }.freeze
  COLORS = ['#00bc87', '#008fff', '#ffbd36', '#ff8b2d', '#f65362'].freeze

  def self.trend_points(date)
    TicketJourneyPerformance.completed_month_ends(date).map do |day|
      { date: day,
        open: 0, incidents: 0, non_merge: 0, unknown: 0 }
    end
  end

  # Reuse each candidate's loaded scalar history. Retain only monthly aggregates,
  # including tickets closed or reassigned by the main report date.
  def self.accumulate_trend!(points, issue, history, statuses, date, visible_values, owner_ids)
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
      point[:open] += 1
      events.each do |event|
        next if event[:at] > cutoff

        point[:incidents] += 1
        point[:non_merge] += 1 if event[:merge_conflict] == false
        point[:unknown] += 1 if event[:merge_conflict].nil?
      end
    end
    events
  end

  def self.finish_trend!(points)
    points.each do |point|
      point[:ratio] = point[:open].positive? ? point[:incidents] * 100.0 / point[:open] : nil
      point[:adjusted_ratio] = point[:open].positive? && point[:unknown].zero? ? point[:non_merge] * 100.0 / point[:open] : nil
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
      event[:merge_conflict] = event[:reason] ? !!event[:reason].match(/\bmerge[\s_-]*conflicts?\b/i) : nil
    end
    events
  end

  def self.calculate(rows)
    open = rows.select { |row| eligible?(row) }
    sets = { 'returns_open' => open }
    0.upto(4) { |i| sets["returns_#{i}"] = open.select { |row| [row[:return_count], 4].min == i } }
    sets['repeats_all'] = open.select { |row| row[:repeat_count].positive? }
    1.upto(3) { |i| sets["repeats_#{i}"] = open.select { |row| [row[:repeat_count], 3].min == i } }
    sets['return_incidents'] = open.select { |row| row[:return_count].positive? }
    sets['non_merge_incidents'] = open.select { |row| row[:events].any? { |event| event[:merge_conflict] == false } }
    incidents = open.sum { |row| row[:return_count] }
    unknown = open.sum { |row| row[:events].count { |event| event[:merge_conflict].nil? } }
    non_merge = open.sum { |row| row[:events].count { |event| event[:merge_conflict] == false } }
    {
      open: open.size, incidents: incidents, repeats: open.sum { |row| row[:repeat_count] },
      with_repeats: sets['repeats_all'].size, non_merge: non_merge, unknown: unknown, sets: sets,
      ratio: open.any? ? incidents * 100.0 / open.size : nil,
      adjusted_ratio: open.any? && unknown.zero? ? non_merge * 100.0 / open.size : nil
    }
  end
end
