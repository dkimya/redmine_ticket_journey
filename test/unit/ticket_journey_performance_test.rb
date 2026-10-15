require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceTest < ActiveSupport::TestCase
  test 'mean targets require every selected owner and reject unusable values' do
    assert_equal 15.0, TicketJourneyPerformance.average_targets([10, 20])
    assert_equal 8.5, TicketJourneyPerformance.average_targets([8.5])
    [nil, 0, -1, Float::INFINITY, Float::NAN, '10'].each do |invalid|
      assert_nil TicketJourneyPerformance.average_targets([10, invalid])
    end
    assert_nil TicketJourneyPerformance.average_targets([])
  end

  def row(**values)
    { open: true, done: false, started: false, due: nil, weight: 5.0,
      missing_weight: false, delivered_at: nil }.merge(values)
  end

  test 'open groups partition totals and due soon includes today but not day three' do
    date = Date.new(2026, 10, 13)
    rows = [row, row(due: date), row(due: date + 2), row(due: date + 3),
            row(due: date - 1, started: true), row(due: date - 1)]
    result = TicketJourneyPerformance.calculate(rows, date, nil)
    assert_equal [6, 4, 1, 1], result[:groups].map(&:size)
    assert_equal 2, result[:due_soon]
    assert_equal 1, result[:missing_due]
    assert_equal result[:groups], %w[open not_overdue started untouched].map { |key| result[:detail_sets][key] }
    %w[due_soon missing_due missing_weight missing_delivery].each do |key|
      assert_equal result[key.to_sym], result[:detail_sets][key].size
    end
    assert_equal rows[1, 2], result[:detail_sets]['due_soon']
    assert_equal 0.0, result[:monthly_count]
  end

  test 'delivery numerator excludes future due work archived work and reopened tickets' do
    date = Date.new(2026, 10, 13)
    rows = [row(open: false, done: true, due: date),
            row(open: false, done: true, due: date + 1),
            row(open: false, status_name: 'Archived', due: date), row(due: date)]
    result = TicketJourneyPerformance.calculate(rows, date, nil)
    assert_equal 2, result[:due].size
    assert_equal 1, result[:done].size
    assert_equal result[:done], result[:detail_sets]['done']
    assert_equal result[:due], result[:detail_sets]['due']
  end

  test 'delivery excludes archived and ongoing without removing ongoing from open tickets' do
    date = Date.new(2026, 10, 14)
    ongoing = row(status_name: 'Ongoing', due: date, weight: 13, delivered_at: date - 1)
    archived = row(status_name: 'Archived', open: false, due: date, weight: 21, delivered_at: date - 1)
    completed = row(status_name: 'Done / Closed', open: false, done: true, due: date, weight: 8, delivered_at: date.beginning_of_month - 1)
    pending = row(status_name: 'Pending', due: date, weight: 5)
    result = TicketJourneyPerformance.calculate([ongoing, archived, completed, pending], date, date.beginning_of_month)
    assert_equal [ongoing, pending], result[:groups].first
    assert_equal [completed, pending], result[:detail_sets]['due']
    assert_equal [completed], result[:detail_sets]['done']
    assert_equal [completed], result[:detail_sets]['delivered']
    assert_equal 13, TicketJourneyPerformance.weight(result[:due])
    assert_equal 8, TicketJourneyPerformance.weight(result[:done])
    assert_in_delta 1.0 / 3, result[:monthly_count], 0.0001
  end

  test 'delivery exclusion follows report date status rather than current archived status' do
    date = Date.new(2026, 10, 14)
    statuses = { '5' => stub(name: 'Done / Closed', is_closed: true), '7' => stub(name: 'Archived', is_closed: true) }
    issue = stub(id: 1, created_on: date.in_time_zone - 5.days, status_id: 7, due_date: date)
    issue.stubs(:start_date).returns(nil)
    issue.stubs(:custom_value_for).with(57).returns(stub(value: '7'))
    history = [TicketJourneyPerformance::HistoryJournal.new(1, (date + 1).in_time_zone, [
      TicketJourneyPerformance::HistoryDetail.new('attr', 'status_id', '5', '7')
    ])]
    past = TicketJourneyPerformance.snapshot(issue, date, statuses, history: history, visible_values: [])
    later = TicketJourneyPerformance.snapshot(issue, date + 1, statuses, history: history, visible_values: [])
    assert_equal [past], TicketJourneyPerformance.calculate([past], date, nil)[:done]
    assert_empty TicketJourneyPerformance.calculate([later], date + 1, nil)[:due]
  end

  test 'stopped is an overlapping open subset with matching drill down' do
    date = Date.new(2026, 10, 14)
    rows = [row(status_name: 'On-Hold', due: date - 1, started: true),
            row(status_name: 'Pending', due: date - 1),
            row(status_name: 'Pending', due: date + 1),
            row(status_name: 'Ongoing'), row(status_name: 'On-Hold', open: false)]
    result = TicketJourneyPerformance.calculate(rows, date, nil)
    assert_equal 3, result[:stopped]
    assert_equal rows.first(3), result[:detail_sets]['stopped']
    assert_equal [4, 2, 1, 1], result[:groups].map(&:size)
    assert_equal 20, TicketJourneyPerformance.weight(result[:groups].first)
  end

  test 'only In Progress history establishes started by the report date' do
    date = Date.new(2026, 10, 14)
    status = Struct.new(:name, :is_closed)
    statuses = { '1' => status.new('To-Do', false), '2' => status.new('In Progress', false),
                 '3' => status.new('Review ', false), '4' => status.new('Pending', false),
                 '5' => status.new('On-Hold', false) }
    issue = stub(id: 1, created_on: date.in_time_zone - 5.days, status_id: 3, due_date: date - 1)
    issue.stubs(:start_date).returns(nil)
    issue.stubs(:custom_value_for).with(57).returns(stub(value: '7'))
    snapshot = lambda do |history|
      TicketJourneyPerformance.snapshot(issue, date, statuses, history: history, visible_values: [])
    end
    change = lambda do |id, time, from, to|
      TicketJourneyPerformance::HistoryJournal.new(id, time, [
        TicketJourneyPerformance::HistoryDetail.new('attr', 'status_id', from, to)
      ])
    end
    assert_not snapshot.call([])[:started], 'Review alone does not imply In Progress'
    assert_not snapshot.call([change.call(1, date.in_time_zone, '1', '3')])[:started]
    assert snapshot.call([change.call(1, date.in_time_zone, '2', '3')])[:started]

    issue.stubs(:status_id).returns(2)
    assert snapshot.call([])[:started], 'As-of In Progress is sufficient even without a transition'
    future_start = [change.call(1, (date + 1).in_time_zone, '1', '2')]
    assert_not snapshot.call(future_start)[:started], 'Future start must not affect a past report'

    issue.stubs(:status_id).returns(5)
    history = [change.call(1, date.in_time_zone - 1.day, '2', '4'),
               change.call(2, (date + 1).in_time_zone, '4', '5')]
    historical = snapshot.call(history)
    assert_equal 'Pending', historical[:status_name]
    assert historical[:started], 'Stopping does not erase earlier In Progress'
    assert_equal 1, TicketJourneyPerformance.calculate([historical], date, nil)[:stopped]
  end

  test 'monthly window includes complete boundary months and zero delivery months only' do
    date = Date.new(2026, 10, 15)
    first = row(open: false, done: true, delivered_at: Date.new(2026, 7, 1), weight: 6, start_date: nil)
    no_weight = row(open: false, done: true, delivered_at: Date.new(2026, 7, 31), weight: 0, missing_weight: true)
    last = row(open: false, done: true, delivered_at: Date.new(2026, 9, 30), weight: 9, start_date: date + 1)
    rows = [first, no_weight, last,
      row(open: false, done: true, delivered_at: Date.new(2026, 6, 30)),
      row(open: false, done: true, delivered_at: Date.new(2026, 10, 1)),
      row(open: false, done: true),
      row(done: false, delivered_at: Date.new(2026, 9, 29)),
      row(done: true, status_name: 'Archived', delivered_at: Date.new(2026, 9, 29)),
      row(done: true, status_name: 'Ongoing', delivered_at: Date.new(2026, 9, 29))]
    result = TicketJourneyPerformance.calculate(rows, date)
    assert_equal Date.new(2026, 7, 1), result[:monthly_start_date]
    assert_equal Date.new(2026, 9, 30), result[:monthly_end_date]
    assert_equal [first, no_weight, last], result[:detail_sets]['delivered']
    assert_equal [first, last], result[:detail_sets]['delivered_weight']
    assert_equal 1.0, result[:monthly_count] # August has no deliveries; still / 3.
    assert_equal 5.0, result[:monthly_weight]
    assert_equal 1, result[:missing_delivery]
    assert_equal result, TicketJourneyPerformance.calculate(rows, date, date + 1)
    assert_equal result, TicketJourneyPerformance.calculate(rows, date, nil)
    first[:weight] = 12
    assert_equal 7.0, TicketJourneyPerformance.calculate(rows, date)[:monthly_weight]
  end

  test 'monthly calendar window handles leap years year boundaries and dates within the month' do
    [[Date.new(2024, 3, 1), Date.new(2023, 12, 1), Date.new(2024, 2, 29)],
     [Date.new(2024, 3, 31), Date.new(2023, 12, 1), Date.new(2024, 2, 29)],
     [Date.new(2026, 1, 15), Date.new(2025, 10, 1), Date.new(2025, 12, 31)]].each do |date, first, last|
      result = TicketJourneyPerformance.calculate([], date)
      assert_equal first, result[:monthly_start_date]
      assert_equal last, result[:monthly_end_date]
      assert_equal 0.0, result[:monthly_count]
      assert_equal 0.0, result[:monthly_weight]
    end
  end

  test 'snapshot reverses later status and owner changes but preserves current due date and weight' do
    date = Date.new(2026, 10, 13)
    detail = Struct.new(:property, :prop_key, :old_value, :value)
    journal = Struct.new(:id, :created_on, :details)
    status = Struct.new(:name, :is_closed)
    statuses = { '2' => status.new('In Progress', false), '5' => status.new('Done / Closed', true) }
    issue = mock('issue')
    issue.stubs(:id).returns(1)
    issue.stubs(:created_on).returns(date.in_time_zone - 2.days)
    issue.stubs(:status_id).returns(5)
    issue.stubs(:due_date).returns(date - 1)
    issue.stubs(:start_date).returns(nil)
    issue.stubs(:custom_value_for).with(57).returns(Struct.new(:value).new('9'))
    issue.stubs(:visible_custom_field_values).returns([Struct.new(:custom_field, :value).new(Struct.new(:id).new(70), '13')])
    issue.stubs(:journals).returns([journal.new(1, (date + 1).in_time_zone, [
      detail.new('attr', 'status_id', '2', '5'), detail.new('cf', '57', '', '9')
    ])])
    result = TicketJourneyPerformance.snapshot(issue, date, statuses)
    assert_equal '', result[:owner_id]
    assert result[:open]
    assert result[:started]
    assert_not result[:done]
    assert_equal date - 1, result[:due]
    assert_equal 13, result[:weight]
    assert_nil result[:delivered_at]
    # The production path supplies compact history and must not lazy-load journals.
    history = issue.journals
    issue.unstub(:journals)
    issue.expects(:journals).never
    assert_equal result, TicketJourneyPerformance.snapshot(issue, date, statuses, history: history)
  end
end
