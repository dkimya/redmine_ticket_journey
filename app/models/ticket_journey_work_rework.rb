# Attribute visible work-date hours to a workflow status before rolling up phases.
class TicketJourneyWorkRework
  PHASES = %i[design development test unclassified].freeze
  STATUS_PHASES = {
    new: :design, todo: :design, in_progress: :development, review: :development,
    feedback: :test, ready_merge: :test, final_check: :test, done: :test
  }.freeze

  def self.classify(issue, history, statuses, cutoff, hours)
    changes = history.flat_map do |journal|
      journal.details.filter_map do |detail|
        [journal.created_on.in_time_zone, detail] if detail.property == 'attr' && detail.prop_key == 'status_id'
      end
    end
    returns = TicketJourneyPerformanceReturns.events_for(issue, history, statuses, cutoff,
      reason_value: nil, reason_visible: false).map { |event| event[:journal_detail_id] }.to_set
    status_id = changes.empty? ? issue.status_id.to_s : changes.first.last.old_value.to_s
    visited = Set[status_id]
    repeated = Set.new
    change_index = 0
    created_on = issue.created_on.in_time_zone.to_date

    hours.sort_by(&:first).map do |day, amount|
      classifications = Set.new
      day_start = day.in_time_zone
      while (change = changes[change_index]) && change.first.to_date <= day
        at, detail = change
        classifications << bucket(status_id, repeated, statuses) if at > day_start
        repeated = visited.dup if returns.include?(detail.id)
        status_id = detail.value.to_s
        visited.add(status_id)
        change_index += 1
      end
      classifications << bucket(status_id, repeated, statuses)
      phase, kind = classifications.size == 1 && day >= created_on ? classifications.first : [:unclassified, :unknown]
      [day, phase, kind, amount]
    end
  end

  def self.bucket(status_id, repeated, statuses)
    role = TicketJourney::ReturnCount.status_role(statuses[status_id]&.name)
    phase = STATUS_PHASES[role]
    phase ? [phase, repeated.include?(status_id) ? :rework : :work] : [:unclassified, :unknown]
  end

  def self.summary
    { count: 0, weight: 0.0, missing_weight: 0, unavailable: 0, owner_hours: 0.0,
      hours: PHASES.to_h { |phase| [phase, { work: 0.0, rework: 0.0, unknown: 0.0 }] } }
  end

  def self.add!(summary, row, entries, owner_hours, cutoff, time_allowed)
    summary[:count] += 1
    summary[:weight] += row[:weight]
    summary[:missing_weight] += 1 if row[:missing_weight]
    unless time_allowed
      summary[:unavailable] += 1
      return
    end

    entries.each do |day, phase, kind, amount|
      summary[:hours][phase][kind] += amount if day <= cutoff
    end
    owner_hours.each { |day, amount| summary[:owner_hours] += amount if day <= cutoff }
  end

  def self.total(summary, kind = nil, phase = nil)
    buckets = phase ? [summary[:hours].fetch(phase)] : summary[:hours].values
    buckets.sum { |bucket| kind ? bucket.fetch(kind) : bucket.values.sum }
  end

  def self.rework_percent(summary, phase = nil)
    return if summary[:unavailable].positive?

    classified = total(summary, :work, phase) + total(summary, :rework, phase)
    100.0 * total(summary, :rework, phase) / classified if classified.positive?
  end
end
