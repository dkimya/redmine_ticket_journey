# Returns quality for the exact Periodic Tickets completed populations.
class TicketJourneyPeriodicReturns
  LABELS = TicketJourneyPerformanceReturns::LABELS.merge(
    'returns_open' => 'Expected Done Tickets',
    'return_incidents' => 'Expected Done Tickets with at Least One Return',
    'total_open' => 'Total Done Tickets (Expected + Other)',
    'total_return_incidents' => 'Total Done Tickets with at Least One Return',
    'trend_expected' => 'Expected Done Completion Cohort',
    'trend_returned' => 'Returned Tickets in Expected Done Completion Cohort'
  ).except('non_merge_incidents').freeze

  def self.enrich(row, issue, history, statuses, last_day, values)
    reason = values.find { |value| value.custom_field.id == 66 }
    events = TicketJourneyPerformanceReturns.events_for(issue, history, statuses, last_day,
      reason_value: reason&.value, reason_visible: !reason.nil?)
    row.merge(events: events, return_count: events.size, repeat_count: events.count { |event| event[:repeat] })
  end

  def self.calculate(ticket_report, first_day, last_day)
    expected = TicketJourneyPerformanceReturns.summarize(ticket_report[:sets].fetch('completed'))
    total = TicketJourneyPerformanceReturns.summarize(ticket_report[:sets].fetch('actual'))
    sets = expected[:sets].except('non_merge_incidents')
      .merge('total_open' => total[:sets]['returns_open'], 'total_return_incidents' => total[:sets]['return_incidents'])
    { expected: expected, total: total, sets: sets,
      trends: intervals(first_day, last_day).map do |first_at, last_at|
        cohort = cohort_rows(sets['returns_open'], first_at, last_at)
        result = TicketJourneyPerformanceReturns.summarize(cohort)
        { start: first_at, date: last_at, population: result[:population],
          returned: result[:returned], incidents: result[:incidents], ratio: result[:ratio] }
      end }
  end

  def self.intervals(first_day, last_day)
    previous = first_day
    TicketJourneyPeriodicTickets.trend_dates(first_day, last_day).drop(1).map do |day|
      interval = [previous, day]
      previous = day + 1
      interval
    end
  end

  def self.cohort_rows(rows, first_day, last_day)
    rows.select { |row| row[:delivered_at].between?(first_day, last_day) }
  end
end
