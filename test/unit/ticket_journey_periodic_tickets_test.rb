require File.expand_path('../test_helper', __dir__)

class TicketJourneyPeriodicTicketsTest < ActiveSupport::TestCase
  setup do
    @first = Date.new(2026, 3, 1)
    @last = Date.new(2026, 3, 31)
  end

  test 'distinct package categories reconcile counts weights delivery and debt' do
    rows = [row(1, due: @first - 1, beginning_open: true, hotfix: true, done: true, delivered_at: @first),
      row(2, hotfix: true, assigned_on: @first + 1, done: true, delivered_at: @last),
      row(3, assigned_on: @first - 10),
      row(4, due: nil, done: true, delivered_at: @last),
      row(5, due: @last + 1, done: true, delivered_at: @last),
      row(6, status_name: 'On-Hold'), row(7, status_name: 'Ongoing'), row(8, status_name: 'Archived')]
    report = calculate(rows + [rows.first])
    assert_equal [1], ids(report, 'beginning')
    assert_equal [2], ids(report, 'hotfix')
    assert_equal [3], ids(report, 'planned')
    assert_equal [1, 2, 3], ids(report, 'expected')
    assert_equal [1, 2], ids(report, 'completed')
    assert_equal [4, 5], ids(report, 'other')
    assert_equal [1, 2, 4, 5], ids(report, 'actual')
    assert_equal [3], ids(report, 'debt')
    assert_equal [3], ids(report, 'still_open')
    assert_equal [6, 7, 8], ids(report, 'excluded')
    assert_equal 15.0, report[:summaries]['expected'][:weight]
    assert_equal 20.0, report[:summaries]['actual'][:weight]
    assert_equal report[:summaries]['expected'][:count], report[:summaries]['completed'][:count] + report[:summaries]['debt'][:count]
    expected_metric = TicketJourneyPeriodicTickets.metric_rows(report, :count).find { |metric| metric[:key] == 'expected' }
    assert_equal(-1, expected_metric[:deviation][:value])
    assert_in_delta(-100.0 / 3, expected_metric[:deviation][:percent])
  end

  test 'hotfix timing needs recorded assignment and has an explicit date fallback' do
    report = calculate([row(1, hotfix: true, due: nil, assigned_on: @first),
      row(2, hotfix: true, due: @last + 2, assigned_on: @last),
      row(3, hotfix: true, due: nil, assigned_on: nil),
      row(4, hotfix: true, due: nil, assigned_on: @first - 1),
      row(5, hotfix: true, due: @last, assigned_on: nil)])
    assert_equal [1, 2], ids(report, 'hotfix')
    assert_equal [5], ids(report, 'planned')
    assert_equal [3, 5], ids(report, 'missing_assignment')
    assert_equal [@first, @last], report[:sets]['hotfix'].map { |item| item[:expected_on] }
  end

  test 'RSD and RED completions qualify but reopened or outside-period closures do not' do
    report = calculate([row(1, done: true, delivered_at: @first), row(2, done: true, delivered_at: @last),
      row(3, done: true, delivered_at: @first - 1), row(4, done: true, delivered_at: @last + 1),
      row(5, done: false, delivered_at: @last), row(6, done: true, delivered_at: nil, current_open: false),
      row(7, closed_before: true, done: true, delivered_at: @last)])
    assert_equal [1, 2], ids(report, 'completed')
    assert_equal [3, 4, 5, 6], ids(report, 'debt')
    assert_equal [3, 4, 5], ids(report, 'still_open')
    assert_equal [6], ids(report, 'missing_completion')
    assert_equal [7], ids(report, 'other')
  end

  test 'opening debt uses due before RSD and eligible opening status' do
    report = calculate([row(1, beginning_open: true, due: @first - 1),
      row(2, beginning_open: true, due: @first), row(3, beginning_open: true, due: nil),
      row(4, beginning_open: false, due: @first - 1)])
    assert_equal [1], ids(report, 'beginning')
    assert_equal [2], ids(report, 'planned')
    assert_equal [1, 2], ids(report, 'expected')
  end

  test 'missing weights retain tickets and do not add weight' do
    report = calculate([row(1, weight: 0.0, missing_weight: true), row(2, weight: 8.0)])
    assert_equal 2, report[:summaries]['expected'][:count]
    assert_equal 8.0, report[:summaries]['expected'][:weight]
    assert_equal 1, report[:summaries]['expected'][:missing_weight]
    assert_equal [1], ids(report, 'missing_weight')
  end

  test 'trends use due and completion dates and reconcile at RED without Other Done' do
    report = calculate([row(1, beginning_open: true, due: @first - 1, done: true, delivered_at: @first),
      row(2, due: @last, done: true, delivered_at: @first + 2),
      row(3, due: nil, done: true, delivered_at: @first)])
    opening = report[:trends].first
    assert_equal @first - 1, opening[:date]
    assert_equal 1, opening[:expected_count]
    assert_equal 0, opening[:completed_count]
    assert_equal [1], TicketJourneyPeriodicTickets.trend_rows(report[:sets], 'expected', opening[:date]).map { |item| item[:id] }
    report[:trends].each do |point|
      %w[expected completed].each do |kind|
        contributors = TicketJourneyPeriodicTickets.trend_rows(report[:sets], kind, point[:date])
        assert_equal contributors.size, point["#{kind}_count".to_sym]
        assert_equal TicketJourneyPerformance.weight(contributors), point["#{kind}_weight".to_sym]
      end
    end
    assert_equal 1, report[:trends][1][:expected_count]
    assert_equal 1, report[:trends][1][:completed_count]
    ending = report[:trends].last
    assert_equal @last, ending[:date]
    [:count, :weight].each do |measure|
      assert_equal report[:summaries]['expected'][measure], ending["expected_#{measure}".to_sym]
      assert_equal report[:summaries]['completed'][measure], ending["completed_#{measure}".to_sym]
    end
  end

  test 'single day and long periods retain final endpoints and chronological buckets' do
    assert_equal [@first - 1, @first], TicketJourneyPeriodicTickets.trend_dates(@first, @first)
    dates = TicketJourneyPeriodicTickets.trend_dates(Date.new(2025, 12, 15), Date.new(2026, 12, 10))
    assert_equal Date.new(2025, 12, 14), dates.first
    assert_equal Date.new(2026, 12, 10), dates.last
    assert_equal dates.sort.uniq, dates
    assert_operator dates.size, :<=, 14
    assert_includes dates, Date.new(2026, 2, 28)
  end

  test 'deviations use metric direction and zero plan never manufactures a percentage' do
    assert_equal({ value: -2, percent: nil }, TicketJourneyPeriodicTickets.deviation(0, 2, :plan_minus_actual))
    assert_equal({ value: -2, percent: -20.0 }, TicketJourneyPeriodicTickets.deviation(10, 8))
    assert_equal({ value: 2, percent: 20.0 }, TicketJourneyPeriodicTickets.deviation(10, 8, :plan_minus_actual))
    report = calculate([row(1, beginning_open: true, due: @first - 1), row(2)])
    metrics = TicketJourneyPeriodicTickets.metric_rows(report, :count).index_by { |metric| metric[:key] }
    assert_equal 0, metrics['beginning'][:plan]
    assert_equal 2, metrics['expected'][:plan]
    assert_equal(-1, metrics['beginning'][:deviation][:value])
  end

  test 'assignment uses latest genuine transition into current owner by RED without creation fallback' do
    history = [change(1, @first - 5, '', '1'), change(2, @first + 2, '1', '2'),
      change(3, @first + 3, '2', '1'), change(4, @first + 4, '1', '1'),
      change(5, @last + 1, '2', '1')]
    assert_equal @first + 3, TicketJourneyPeriodicTickets.assignment_date(history, '1', @last)
    assert_nil TicketJourneyPeriodicTickets.assignment_date([], '1', @last)
    assert_nil TicketJourneyPeriodicTickets.assignment_date(history, '3', @last)
  end

  private

  def row(id, **options)
    { id: id, owner_id: '1', due: @first + 10, beginning_open: false, closed_before: false,
      hotfix: false, assigned_on: @first - 10, done: false, delivered_at: nil,
      status_name: 'In Progress', current_open: true, weight: 5.0, missing_weight: false }.merge(options)
  end

  def calculate(rows)
    TicketJourneyPeriodicTickets.calculate(rows, @first, @last)
  end

  def ids(report, key)
    report[:sets].fetch(key).map { |item| item[:id] }.sort
  end

  def change(id, day, old_id, new_id)
    TicketJourneyPerformance::HistoryJournal.new(id, day.in_time_zone, [
      TicketJourneyPerformance::HistoryDetail.new('cf', '57', old_id, new_id, id)
    ])
  end
end
