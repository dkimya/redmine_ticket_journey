# Five completed-month points per owner; no persistent counters or issue rows.
class TicketJourneyPerformanceTimeTrends
  def self.points(date)
    TicketJourneyPerformanceTime.trend_points(date).map do |point|
      point.merge(logged_hours: 0.0, open_count: 0, open_owner_hours: 0.0, open_unavailable: 0)
    end
  end

  def self.accumulate!(point, snapshot, ticket_hours:, owner_hours:)
    TicketJourneyPerformanceTime.add_productivity!(point, snapshot, ticket_hours)
    return unless snapshot[:open] && !TicketJourneyPerformance::OPEN_EXCLUDED_STATUSES.include?(snapshot[:status_name])

    point[:open_count] += 1
    if owner_hours.nil?
      point[:open_unavailable] += 1
    else
      point[:open_owner_hours] += owner_hours
    end
  end

  # Independent of Ticket Owner, tracker and status: all visible linked-ticket
  # entries booked by selected users in the visible project hierarchy.
  def self.logged_hours_for(project_ids, owner_ids, from, through)
    issues = Issue.visible(User.current).where(project_id: project_ids).select(:id)
    TimeEntry.visible(User.current).where(issue_id: issues, user_id: owner_ids)
      .where(spent_on: from..through)
      .where('time_entries.hours >= 0 AND time_entries.hours <= ?', Float::MAX)
      .group(:user_id, :spent_on).sum(:hours)
  end

  def self.add_logged_hours!(owners, totals)
    totals.each do |(user_id, day), hours|
      number = hours.to_f
      next unless number.finite?

      point = owners.fetch(user_id.to_s, []).find { |item| day >= item[:date].beginning_of_month && day <= item[:date] }
      point[:logged_hours] += number if point
    end
  end

  def self.finish!(points, time_visible:)
    TicketJourneyPerformanceTime.finish_trend!(points)
    points.each do |point|
      # Calendar-week equivalents include all days and zero-log weeks. This avoids
      # inflating the mean by counting only weeks that happen to contain entries.
      point[:week_equivalents] = point[:date].day / 7.0
      point[:weekly_average] = time_visible ? point[:logged_hours] / point[:week_equivalents] : nil
      point[:open_average] = if point[:open_count].positive? && point[:open_unavailable].zero?
        point[:open_owner_hours] / point[:open_count]
      end
    end
  end
end
