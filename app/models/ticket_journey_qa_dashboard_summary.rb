# The dashboard and its drill-downs use the same ticket sets. A gate can
# contribute once per ticket; the most recent verdict determines its outcome.
class TicketJourneyQaDashboardSummary
  ROLES = TicketJourneyQaReport::GATE_ROLES.values.freeze
  METRICS = {
    'tickets' => 'Scoped tickets', 'bugs' => 'Bugs', 'found' => 'Bugs found',
    'false_passes' => 'False Passes', 'escapes' => 'Test Escapes', 'score' => 'QA score contributors',
    'tested' => 'Tested', 'passed' => 'Passed', 'returned' => 'Returned',
    'queue' => 'Test queue', 'due_soon' => 'Close to due date', 'duration' => 'Calendar duration',
    'work' => 'Logged work', 'rework' => 'Logged rework', 'hours' => 'Logged time',
    'efficiency' => 'Processed CW/h'
  }.freeze

  def initialize(report, roles: ROLES)
    @report = report
    @roles = roles
    @bugs = report.bugs.reject { |row| TicketJourneyQaReport::REJECTED_BUGS.include?(row[:status]) }
    @false_passes = report.returns.select { |row| row[:event][:reason] == TicketJourneyQaReport::FALSE_PASS_REASON }
    @inventory_bugs = report.dashboard_rows.select { |row| row[:issue].tracker.name == 'Bug' }
  end

  def calculate(actor: nil, range: nil)
    rows = in_range(@report.dashboard_rows, range)
    bugs = in_range(@bugs, range)
    found = bugs.select { |row| row[:qa_find] && (!actor || row[:finder_id] == actor) }
    escapes = bugs.select { |row| row[:escape] && (!actor || row[:escape_actor] == actor) }
    false_passes = in_range(@false_passes, range).select { |row| !actor || row[:event][:pass][:user_id] == actor }
    queue = actor || range ? [] : @report.queue
    gates = rows.to_h do |row|
      events = actor ? row[:gates].select { |gate| gate[:actor] == actor } : row.fetch(:workflow_gates)
      [row[:issue].id, events.index_by { |gate| gate[:role] }]
    end
    workflow = ROLES.to_h do |role|
      tested = rows.select { |row| gates[row[:issue].id].key?(role) }
      waiting = queue.select { |row| TicketJourneyQaReport::GATE_ROLES[row[:status]] == role }
      [role, {
        tested: tested,
        passed: tested.select { |row| gates[row[:issue].id][role][:outcome] == :passed },
        returned: tested.select { |row| gates[row[:issue].id][role][:outcome] == :returned },
        queue: waiting, due_soon: waiting.select { |row| row[:close_to_due] }
      }]
    end
    duration_by_role = workflow.transform_values { {} }
    workflow.each do |role, metrics|
      metrics[:tested].each { |row| duration_by_role[role][row[:issue].id] = gates[row[:issue].id][role][:days] }
      metrics[:queue].each { |row| duration_by_role[role][row[:issue].id] = row[:age] }
      metrics[:duration] = (metrics[:tested] + metrics[:queue]).uniq { |row| row[:issue].id }
        .select { |row| duration_by_role[role][row[:issue].id] }
    end
    hours, time_rows, paired = calculate_time(rows, actor)
    scored = found.reject { |row| row[:credit].nil? } +
      escapes.reject { |row| row[:escape_points].nil? } +
      false_passes.reject { |row| row[:points].nil? || row[:audit].last&.excluded? }
    points = { found: found.sum { |row| row[:credit].to_f }, escapes: -escapes.sum { |row| row[:escape_points].to_f },
      false_passes: -false_passes.sum { |row| row[:points].to_f } }
    points[:total] = points[:found] - points[:false_passes] - points[:escapes]
    applicable_durations = duration_by_role.values_at(*@roles)
    durations = applicable_durations.flat_map { |values| values.values.compact }
    timed_ids = applicable_durations.flat_map { |values| values.reject { |_id, value| value.nil? }.keys }.to_set
    {
      sets: { tickets: rows, bugs: in_range(@inventory_bugs, range), found: found, escapes: escapes,
        false_passes: false_passes, score: scored,
        tested: rows.select { |row| row[:gates].any? { |gate| !actor || gate[:actor] == actor } },
        duration: rows.select { |row| timed_ids.include?(row[:issue].id) }, queue: queue,
        hours: time_rows[:hours], work: time_rows[:work], rework: time_rows[:rework], efficiency: paired[:rows] },
      workflow: workflow, points: points, hours: hours, paired: paired,
      duration_by_role: duration_by_role.transform_values { |values| TicketJourneyPeriodicTime.mean(values.values.compact) },
      duration: TicketJourneyPeriodicTime.mean(durations),
      rework_share: (hours[:rework] * 100.0 / hours[:total] if hours[:total].positive?),
      efficiency: (paired[:weight] / paired[:hours] if paired[:hours].positive?)
    }
  end

  def self.ticket_count(rows)
    rows.uniq { |row| row[:issue].id }.size
  end

  def self.ticket_weight(rows)
    rows.uniq { |row| row[:issue].id }.sum { |row| row[:weight].to_f }
  end

  private

  def in_range(rows, range)
    return rows unless range

    rows.select { |row| row[:completed_on] && range.cover?(row[:completed_on]) }
  end

  def calculate_time(rows, actor)
    hours = { work: 0.0, rework: 0.0, total: 0.0 }
    time_rows = { work: [], rework: [], hours: [] }
    paired = { hours: 0.0, weight: 0.0, rows: [] }
    rows.each do |row|
      eligible_actors = row[:gates].map { |gate| gate[:actor] }.to_set
      matched_hours = 0.0
      contributions = row[:testing]
      contributions = contributions.slice(actor) if actor
      work, rework = %i[work rework].map { |kind| contributions.values.sum { |entry| entry[kind] } }
      total = work + rework
      hours[:work] += work
      hours[:rework] += rework
      hours[:total] += total
      time_rows[:work] << row if work.positive?
      time_rows[:rework] << row if rework.positive?
      time_rows[:hours] << row if total.positive?
      next unless row[:weight]

      contributions.each do |id, entry|
        matched_hours += entry[:work] + entry[:rework] if eligible_actors.include?(id)
      end
      next unless matched_hours.positive?

      paired[:hours] += matched_hours
      paired[:weight] += row[:weight]
      paired[:rows] << row
    end
    [hours, time_rows, paired]
  end
end
