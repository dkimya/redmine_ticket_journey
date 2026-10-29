require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceTimeTest < ActiveSupport::TestCase
  test 'area three reconciles active ongoing and archived hours with active-only comparisons' do
    report = TicketJourneyPerformanceTime.calculate([
      row(spent: 28.5, estimate: 66.0, planned: 55.1),
      row(2, status_name: 'Ongoing', spent: 21.7),
      row(3, status_name: 'Archived', open: false, spent: 5.0)
    ])
    assert_in_delta 55.2, report[:spent], 0.001
    assert_equal 28.5, report[:active_spent]
    assert_equal 21.7, report[:ongoing_spent]
    assert_equal 5.0, report[:archived_spent]
    assert_equal 66.0, report[:estimate]
    assert_equal 37.5, report[:balance]
    assert_equal [1], report[:sets]['time_sv'].map { |ticket| ticket[:id] }
    assert_equal [1], report[:sets]['time_balance'].map { |ticket| ticket[:id] }
    assert_in_delta (55.1 - 28.5) / 55.1 * 100, report[:sv], 0.001
    hidden = TicketJourneyPerformanceTime.calculate([row(status_name: 'Archived', open: false, spent: nil)])
    assert_nil hidden[:archived_spent]
    assert_nil hidden[:spent]
  end

  def calendar(settings = {})
    TicketJourney::WorkingCalendar.new(settings)
  end

  def row(id = 1, **values)
    { id: id, owner_id: '1', open: true, status_name: 'In Progress', done: false,
      priority: 'Urgent', age: 0, estimate: 40.0, spent: 24.0, planned: 28.0,
      exclusions: [], early_hours: 0.0, weight: 8.0, missing_weight: false }.merge(values)
  end

  test 'inclusive schedule matches Hadi example but start date age is zero' do
    start, due, date = Date.new(2026, 10, 5), Date.new(2026, 10, 16), Date.new(2026, 10, 13)
    assert_equal 10, calendar.days(start, due)
    assert_equal 0, calendar.age(start, start)
    assert_equal 6, calendar.age(start, date)
    assert_in_delta 0.7, calendar.elapsed_fraction(start, due, date), 0.000001
    assert_in_delta 0.1, calendar.elapsed_fraction(start, due, start), 0.000001
    assert_equal 1.0, calendar.elapsed_fraction(start, due, due + 20)
    assert_equal 0.0, calendar.elapsed_fraction(start, due, start - 1)
    assert_nil calendar.age(start, start - 1)
  end

  test 'calendar handles nonstandard weekends holidays leap days and empty windows' do
    cal = calendar('performance_working_weekdays' => %w[0 1 2 3 4], 'performance_holidays' => "2026-10-12 Holiday\n2026-10-12 duplicate\n")
    assert_equal 0, cal.days(Date.new(2026, 10, 9), Date.new(2026, 10, 10))
    assert_equal 1, cal.days(Date.new(2026, 10, 11), Date.new(2026, 10, 12))
    assert_equal 2, calendar.days(Date.new(2024, 2, 28), Date.new(2024, 2, 29))
    assert_nil calendar.elapsed_fraction(Date.new(2026, 10, 10), Date.new(2026, 10, 11), Date.new(2026, 10, 11))
    assert_nil calendar.elapsed_fraction(Date.new(2026, 10, 5), Date.new(2026, 10, 5), Date.new(2026, 10, 5))
    start, due = Date.new(2026, 10, 5), Date.new(2026, 10, 16)
    assert_equal calendar.elapsed_fraction(start, due, start, daily_hours: 8), calendar.elapsed_fraction(start, due, start, daily_hours: 4)
  end

  test 'age buckets partition usable starts and open statuses match Tickets and Returns' do
    rows = [0, 15, 16, 30, 31, 60, 61, nil].each_with_index.map { |age, index| row(index, age: age) }
    rows += [row(20, status_name: 'New'), row(21, status_name: 'On-Hold'), row(22, open: false)]
    rows << row(23, status_name: 'Ongoing', priority: 'Immediate')
    report = TicketJourneyPerformanceTime.calculate(rows)
    assert_equal 9, report[:open]
    assert_equal [2, 2, 2, 1], 4.times.map { |index| report[:sets]["time_age_#{index}"].size }
    assert_equal 1, report[:sets]['time_age_excluded'].size
    assert_equal [23], report[:sets]['time_immediate'].map { |entry| entry[:id] }
    assert_equal report[:open], report[:priority]
    assert_equal [23], report[:sets]['time_ongoing'].map { |entry| entry[:id] }
    assert_equal [23], report[:sets]['time_priority_ongoing'].map { |entry| entry[:id] }
  end

  test 'schedule exclusions remove both planned and actual hours while totals remain visible' do
    report = TicketJourneyPerformanceTime.calculate([
      row, row(2, planned: nil, exclusions: ['Set Due Date'], spent: 100.0),
      row(3, planned: nil, spent: nil, exclusions: ['Time unavailable'])
    ])
    assert_equal 124.0, report[:spent]
    assert_equal 1, report[:time_unavailable]
    assert_equal 28.0, report[:planned]
    assert_equal 24.0, report[:actual]
    assert_in_delta 14.285714, report[:sv], 0.000001
    assert_equal 2, report[:sets]['time_sv_excluded'].size
    assert_equal 2, report[:sets]['time_balance'].size
    assert_equal(-44.0, report[:balance])
  end

  test 'estimate exclusion hours reconcile overall spent with balance without treating hidden time as zero' do
    missing = row(2, estimate: nil, spent: 515.3, planned: nil, age: nil,
      exclusions: ['Set a positive finite PM Estimate'])
    report = TicketJourneyPerformanceTime.calculate([row(estimate: 163.0, spent: 108.0), missing])
    assert_in_delta 623.3, report[:spent], 0.000001
    assert_in_delta 515.3, report[:estimate_excluded_spent], 0.000001
    assert_in_delta report[:spent], report[:balance_spent] + report[:estimate_excluded_spent], 0.000001
    assert_equal [2], report[:sets]['time_priority_age_excluded'].map { |entry| entry[:id] }
    report = TicketJourneyPerformanceTime.calculate([missing.merge(spent: nil)])
    assert_nil report[:estimate_excluded_spent]
    assert_equal 1, report[:time_unavailable]
  end

  test 'SV aggregates hours not percentages and invalid denominators remain unavailable' do
    report = TicketJourneyPerformanceTime.calculate([row(planned: 380.0, spent: 475.0)])
    assert_equal(-25.0, report[:sv])
    report = TicketJourneyPerformanceTime.calculate([row(planned: 10.0, spent: 20.0), row(2, planned: 90.0, spent: 60.0)])
    assert_equal 20.0, report[:sv]
    assert_nil TicketJourneyPerformanceTime.calculate([row(planned: 0.0, spent: 4.0)])[:sv]
  end

  test 'enrichment uses current dates and estimates and includes only entries through work date' do
    date = Date.new(2026, 10, 5)
    issue = stub(start_date: date, due_date: date + 4, estimated_hours: 40, priority: stub(name: 'Immediate'))
    entries = [[date - 2, 2.0], [date, 3.0], [date + 1, 9.0]]
    result = TicketJourneyPerformanceTime.enrich(row, issue, date, calendar, entries, true, 8)
    assert_equal 5.0, result[:spent]
    assert_equal 2.0, result[:early_hours]
    assert_equal 8.0, result[:planned]
    assert_equal 0, result[:age]
    result = TicketJourneyPerformanceTime.enrich(row, issue, date, calendar, entries, false, 8)
    assert_nil result[:spent]
    assert_nil result[:planned]
    assert_includes result[:exclusions], 'Logged time unavailable under current permissions'
    issue.stubs(:start_date).returns(date + 1)
    result = TicketJourneyPerformanceTime.enrich(row, issue, date, calendar, entries, true, 8)
    assert_nil result[:age]
    assert_nil result[:planned]
    assert_includes result[:exclusions], 'Start Date is after report date'
    issue.stubs(:start_date).returns(date)
    ongoing = TicketJourneyPerformanceTime.enrich(row(status_name: 'Ongoing'), issue, date, calendar, entries, true, 8)
    assert_nil ongoing[:age]
    assert_equal 5.0, ongoing[:spent]
  end

  test 'productivity reuses monthly completion scope and matches numerator denominator exclusions' do
    date = Date.new(2026, 10, 21)
    points = TicketJourneyPerformanceTime.trend_points(date)
    assert_equal [5, 6, 7, 8, 9], points.map { |point| point[:date].month }
    point = points.last
    delivered = row(done: true, status_name: 'Done / Closed', delivered_at: point[:date])
    TicketJourneyPerformanceTime.add_productivity!(point, delivered, 4.0)
    TicketJourneyPerformanceTime.add_productivity!(point, delivered.merge(id: 2, weight: 24.0), 12.0)
    TicketJourneyPerformanceTime.add_productivity!(point, delivered.merge(id: 3, missing_weight: true), 100.0)
    TicketJourneyPerformanceTime.add_productivity!(point, delivered.merge(id: 4), nil)
    TicketJourneyPerformanceTime.add_productivity!(point, delivered.merge(status_name: 'Archived'), 2.0)
    TicketJourneyPerformanceTime.add_productivity!(point, delivered.merge(done: false, status_name: 'In Progress'), 2.0)
    TicketJourneyPerformanceTime.add_productivity!(point, delivered.merge(delivered_at: point[:date] + 1), 2.0)
    TicketJourneyPerformanceTime.finish_trend!(points)
    assert_equal 2, point[:count]
    assert_equal 2, point[:excluded]
    assert_equal 32.0, point[:weight]
    assert_equal 16.0, point[:hours]
    assert_equal 2.0, point[:productivity]
    assert_nil points.first[:productivity]
    eligible = delivered.merge(spent: 4.0)
    missing_weight = delivered.merge(id: 9, missing_weight: true, spent: 2.0)
    missing_date = delivered.merge(id: 10, delivered_at: nil, spent: 2.0)
    review = TicketJourneyPerformanceTime.calculate([eligible, missing_weight, missing_date], month: point[:date])
    assert_equal [eligible], review[:sets]['time_delivered']
    assert_equal [9, 10], review[:sets]['time_delivered_excluded'].map { |item| item[:id] }
  end
end
