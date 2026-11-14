# Attribute visible work-date hours to a workflow status before rolling up phases.
class TicketJourneyWorkRework
  PHASE_LABELS = {
    design: 'Plan/Design', development: 'Development', test: 'Test',
    communication: 'Communication', unclassified: 'Pending'
  }.freeze
  PHASES = PHASE_LABELS.keys.freeze
  STATUS_PHASES = {
    new: :design, todo: :design, in_progress: :development, review: :development,
    feedback: :test, ready_merge: :test, final_check: :test, done: :test
  }.freeze
  ACTIVITY_PHASES = {
    'design' => :design, 'analysis / design' => :design, 'planning / ideation' => :design,
    'development' => :development, 'review' => :development, 'code review' => :development,
    'test' => :test, 'qa' => :test, 'test / qa / feedback' => :test,
    'internal communication / meeting' => :communication
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

    hours.group_by(&:first).sort_by(&:first).flat_map do |day, entries|
      classifications = Set.new
      day_status_ids = Set.new
      day_start = day.in_time_zone
      return_during_day = false
      while (change = changes[change_index]) && change.first.to_date <= day
        at, detail = change
        if at > day_start
          classifications << bucket(status_id, repeated, statuses)
          day_status_ids.add(status_id)
        end
        if returns.include?(detail.id)
          repeated = visited.dup
          return_during_day ||= at > day_start
        end
        status_id = detail.value.to_s
        visited.add(status_id)
        change_index += 1
      end
      classifications << bucket(status_id, repeated, statuses)
      day_status_ids.add(status_id)
      entries.map do |_date, amount, activity|
        candidates = classifications
        activity_name = activity.to_s.strip.downcase.gsub(/\s*\/\s*/, ' / ')
        activity_phase = ACTIVITY_PHASES[activity_name]
        if candidates.size > 1 && !return_during_day
          matching = candidates.select { |phase, _kind| phase == activity_phase }
          candidates = matching unless matching.empty?
        end
        phase, kind = candidates.size == 1 && day >= created_on ? candidates.first : [:unclassified, :unknown]
        phase = activity_phase if kind == :unknown && return_during_day && activity_phase && day >= created_on
        if day >= created_on && (activity_phase == :communication || activity_name == 'planning / ideation')
          phase = activity_phase
        end
        review = if kind == :unknown && amount.positive?
          reason = if day < created_on
            'Work date precedes ticket creation'
          elsif return_during_day
            'Return occurred during this work date'
          elsif classifications.size > 1
            'Multiple phase or work/rework classifications on this date'
          else
            'Status has no phase mapping'
          end
          { reason: reason, activity: activity, statuses: day_status_ids.map { |id| statuses[id]&.name.presence || 'Unknown status' } }
        end
        [day, phase, kind, amount, review]
      end
    end
  end

  def self.bucket(status_id, repeated, statuses)
    role = TicketJourney::ReturnCount.status_role(statuses[status_id]&.name)
    phase = STATUS_PHASES[role]
    phase ? [phase, repeated.include?(status_id) ? :rework : :work] : [:unclassified, :unknown]
  end

  def self.summary
    { count: 0, weight: 0.0, missing_weight: 0, unavailable: 0, owner_hours: 0.0,
      owner_hours_in_period: 0.0,
      hours: PHASES.to_h { |phase| [phase, { work: 0.0, rework: 0.0, unknown: 0.0 }] } }
  end

  def self.add!(summary, row, entries, owner_hours, cutoff, time_allowed, period_start: nil)
    summary[:count] += 1
    summary[:weight] += row[:weight]
    summary[:missing_weight] += 1 if row[:missing_weight]
    unless time_allowed
      summary[:unavailable] += 1
      return
    end

    entries.each do |day, phase, kind, amount, review|
      next if day > cutoff

      summary[:hours][phase][kind] += amount
      summary[:review] << review.merge(id: row[:id], date: day, hours: amount, phase: phase) if review && summary[:review]
    end
    owner_hours.each do |day, amount|
      next if day > cutoff

      summary[:owner_hours] += amount
      summary[:owner_hours_in_period] += amount if period_start && day >= period_start
    end
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
