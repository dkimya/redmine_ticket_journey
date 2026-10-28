require File.expand_path('../test_helper', __dir__)

class TicketJourneyPeriodicTimeTest < ActiveSupport::TestCase
  setup do
    @first, @last = Date.new(2026, 3, 2), Date.new(2026, 3, 6)
    @settings = { 'performance_periodic_dtc_target' => '10', 'performance_periodic_priority_dtc_target' => '7',
      'performance_periodic_owner_share' => '90' }
    @calendar = TicketJourney::WorkingCalendar.new(@settings)
  end

  test 'eight metrics distinguish full ticket cost personal period hours and calendar DTC' do
    result = report([row(1)])
    metrics = result[:metrics]
    assert_equal 7.0, metrics['dtc'][:actual]
    assert_equal 3.0, metrics['dtc'][:deviation][:value]
    assert_equal 10.0, metrics['ticket_cost'][:plan]
    assert_equal 8.0, metrics['ticket_cost'][:actual]
    assert_equal 9.0, metrics['expected_done_hours'][:plan]
    assert_equal 4.0, metrics['expected_done_hours'][:actual]
    assert_equal 40.0, metrics['total_hours'][:plan]
    assert_equal 4.0, metrics['total_hours'][:actual]
    assert_equal 0.8, metrics['daily_hours'][:actual]
    assert_in_delta 5.0 / 9, metrics['efficiency'][:plan]
    assert_equal 1.25, metrics['efficiency'][:actual]
    assert_empty result[:sets]['expected_done_excluded']
    assert_nil metrics['priority_dtc'][:actual]
  end

  test 'unfinished expectation hours reconcile and remain in efficiency denominator' do
    unfinished = row(2, done: false, status_name: 'In Progress', delivered_at: nil, current_open: true,
      estimate: 20.0, weight: 8.0, owner_logs: { '1' => [[@first + 2, 6.0]] })
    result = report([row(1), unfinished])
    assert_equal 10.0, result[:valid_visible_hours]
    assert_equal 4.0, result[:breakdown]['expected_done']
    assert_equal 6.0, result[:breakdown]['expected_unfinished']
    assert_equal 10.0, result[:reconciliation]['expected_work']
    assert_equal result[:valid_visible_hours], result[:reconciliation].values.sum
    assert_equal 10.0, result[:breakdown].values.sum
    assert_equal 9.0, result[:metrics]['expected_done_hours'][:plan]
    assert_in_delta 13.0 / 27, result[:metrics]['efficiency'][:plan]
    assert_equal 0.5, result[:metrics]['efficiency'][:actual]
    assert_equal [2], result[:sets]['expected_unfinished'].map { |item| item[:id] }
  end

  test 'logged users remain authoritative when current ticket owner changes' do
    reassigned = row(1, owner_id: '2', owner_logs: { '1' => [[@first + 1, 4.0]], '2' => [[@first + 1, 2.0]] })
    previous = report([reassigned], '1')
    current = report([reassigned], '2')
    assert_nil previous[:metrics]['dtc'][:actual]
    assert_equal 0, previous[:metrics]['ticket_cost'][:actual]
    assert_equal 4.0, previous[:metrics]['total_hours'][:actual]
    assert_equal 4.0, previous[:metrics]['other_hours'][:actual]
    assert_equal 0.0, previous[:metrics]['other_hours'][:extra_hours]
    assert_equal 2.0, current[:metrics]['expected_done_hours'][:actual]
    team = TicketJourneyPeriodicTime.aggregate([previous, current], @settings)
    assert_equal 8.0, team[:metrics]['ticket_cost'][:actual]
    assert_equal 6.0, team[:metrics]['total_hours'][:actual]
  end

  test 'Extra Work is per owner nonempty and cannot hide another owners unplanned hours' do
    other = row(2, owner_id: '3', due: nil, owner_logs: { '1' => [[@first + 1, 2.0]], '2' => [[@first + 1, 3.0]] })
    debt = row(3, owner_id: '2', done: false, delivered_at: nil, status_name: 'In Progress', owner_logs: {})
    a, b = report([row(1), other, debt], '1'), report([row(1), other, debt], '2')
    assert_equal 2.0, a[:metrics]['other_hours'][:extra_hours]
    assert_equal(-2.0, a[:metrics]['other_hours'][:deviation][:value])
    assert_equal 3.0, b[:metrics]['other_hours'][:unplanned_hours]
    team = TicketJourneyPeriodicTime.aggregate([a, b], @settings)
    assert_equal 2.0, team[:metrics]['other_hours'][:extra_hours]
    assert_equal 3.0, team[:metrics]['other_hours'][:unplanned_hours]
    assert_equal(-5.0, team[:metrics]['other_hours'][:deviation][:value])
    empty_package = report([other], '1')
    assert_equal 0.0, empty_package[:metrics]['other_hours'][:extra_hours]
    assert_equal 2.0, empty_package[:metrics]['other_hours'][:unplanned_hours]
  end

  test 'missing estimates and hidden weights keep raw hours but exclude paired metrics' do
    result = report([row(1, estimate: nil, missing_weight: true, weight: 0.0)])
    assert_nil result[:metrics]['ticket_cost'][:actual]
    assert_nil result[:metrics]['expected_done_hours'][:actual]
    assert_nil result[:metrics]['efficiency'][:actual]
    assert_equal 4.0, result[:expected_done_raw_hours]
    assert_equal 4.0, result[:metrics]['total_hours'][:actual]
    assert_equal 8.0, result[:all_done_visible_cost]
    %w[cost_excluded expected_done_excluded efficiency_excluded].each do |key|
      assert_equal [1], result[:sets][key].map { |item| item[:id] }
    end
    valid = report([row(2, owner_id: '2', estimate: 20.0, ticket_hours: 25.0, owner_logs: { '2' => [[@first, 5.0]] })], '2')
    team = TicketJourneyPeriodicTime.aggregate([result, valid], @settings)
    assert_equal 20.0, team[:metrics]['ticket_cost'][:plan]
    assert_equal 25.0, team[:metrics]['ticket_cost'][:actual]
    assert_equal 18.0, team[:metrics]['expected_done_hours'][:plan]
    assert_equal 5.0, team[:metrics]['expected_done_hours'][:actual]
  end

  test 'unavailable time never becomes zero while unset targets use confirmed initial values' do
    denied = report([row(1, time_allowed: false, ticket_hours: nil, owner_logs: {})], '1', available: false, any: false)
    assert_nil denied[:metrics]['total_hours'][:actual]
    assert_nil denied[:metrics]['other_hours'][:actual]
    assert_nil denied[:valid_visible_hours]
    assert_nil denied[:metrics]['ticket_cost'][:actual]
    empty_targets = TicketJourneyPeriodicTime.owner_report([row(1)], '1', @first, @last, @calendar, {}, 8,
      total_available: true)
    assert_equal 7.0, empty_targets[:metrics]['dtc'][:plan]
    assert_equal 7.0, empty_targets[:metrics]['dtc'][:actual]
    assert_equal 9.0, empty_targets[:metrics]['expected_done_hours'][:plan]
    assert_equal 4.0, empty_targets[:metrics]['expected_done_hours'][:actual]
    assert_in_delta 5.0 / 9, empty_targets[:metrics]['efficiency'][:plan]
    assert_equal 1.25, empty_targets[:metrics]['efficiency'][:actual]
  end

  test 'zero workdays preserves actual logged hours but leaves capacity daily and zero effort ratios unavailable' do
    first, last = Date.new(2026, 3, 7), Date.new(2026, 3, 8)
    item = row(1, due: first, delivered_at: first, owner_logs: { '1' => [[first, 3.0]] })
    result = TicketJourneyPeriodicTime.owner_report([item], '1', first, last, @calendar, @settings, 8,
      total_available: true)
    assert_nil result[:metrics]['total_hours'][:plan]
    assert_equal 3.0, result[:metrics]['total_hours'][:actual]
    assert_nil result[:metrics]['daily_hours'][:actual]
    zero = report([row(1, owner_logs: {})])
    assert_equal 0, zero[:metrics]['total_hours'][:actual]
    assert_nil zero[:metrics]['efficiency'][:actual]
  end

  test 'team durations daily hours and CW rates use underlying totals not averages of owner ratios' do
    a_rows = [row(1, created_date: @first + 1, weight: 5.0)]
    b_rows = [row(2, owner_id: '2', created_date: @first - 7, weight: 10.0, estimate: 20.0, owner_logs: { '2' => [[@first, 1.0]] }),
      row(3, owner_id: '2', created_date: @first - 7, weight: 10.0, estimate: 20.0, owner_logs: { '2' => [[@first, 1.0]] })]
    a = report(a_rows, '1')
    b = report(b_rows, '2', daily: 4)
    team = TicketJourneyPeriodicTime.aggregate([a, b], @settings)
    assert_in_delta 19.0 / 3, team[:metrics]['dtc'][:actual]
    assert_equal 6.0, team[:metrics]['daily_hours'][:plan]
    assert_equal 0.6, team[:metrics]['daily_hours'][:actual]
    assert_in_delta 25.0 / 6, team[:metrics]['efficiency'][:actual]
    assert_in_delta 25.0 / 45, team[:metrics]['efficiency'][:plan]
  end

  test 'work-date trends partition hours while fixed completion cohorts partition ticket costs and delivered weights' do
    items = [row(1, owner_logs: { '1' => [[@first, 1.0], [@last, 3.0]] })]
    main = report(items)
    intervals = [[@first, @first + 1], [@first + 2, @last]]
    points = intervals.map do |first, last|
      TicketJourneyPeriodicTime.owner_report(items, '1', first, last, @calendar, @settings, 8,
        total_available: true, package: main[:tickets], completion_range: [first, last], comparison_range: [@first, @last])
    end
    assert_equal 4.0, points.sum { |point| point[:metrics]['total_hours'][:actual] }
    assert_equal 8.0, points.sum { |point| point[:metrics]['ticket_cost'][:actual] }
    assert_equal 5.0, points.sum { |point| point[:metrics]['efficiency'][:delivered_weight] }
    assert_equal [1.0, 3.0], points.map { |point| point[:metrics]['efficiency'][:actual_effort] }
    assert_equal 0, points.first[:metrics]['ticket_cost'][:actual]
    assert_equal 8.0, points.last[:metrics]['ticket_cost'][:actual]
  end

  test 'invalid entries are date-scoped and hidden owners remain an explicit logged-user hours review category' do
    invalid = row(1, invalid_logs: { [1, 1, @first] => 1 })
    assert_nil TicketJourneyPeriodicTime.personal_hours(invalid, '1', @first, @last)
    assert_equal 0, TicketJourneyPeriodicTime.personal_hours(invalid, '1', @first + 2, @last)
    result = report([invalid])
    assert_nil result[:metrics]['total_hours'][:actual]
    assert_equal 1, result[:invalid_rows]
    hidden = report([row(2, owner_id: '', owner_visible: false)])
    assert_equal 4.0, hidden[:breakdown]['unclassified']
    assert_equal 4.0, hidden[:metrics]['total_hours'][:actual]
    assert_equal 0, hidden[:tickets][:sets]['expected'].size
    overflowing = row(3, owner_logs: { '1' => [[@first, Float::MAX], [@last, Float::MAX]] })
    assert_nil TicketJourneyPeriodicTime.personal_hours(overflowing, '1', @first, @last)
  end

  test 'later reopening keeps personal effort but removes delivered output and cost' do
    result = report([row(1, current_done: false, current_open: true)])
    assert_equal 4.0, result[:metrics]['total_hours'][:actual]
    assert_equal 4.0, result[:breakdown]['expected_unfinished']
    assert_equal 0.0, result[:metrics]['ticket_cost'][:actual]
    assert_equal 0.0, result[:metrics]['efficiency'][:actual]
    assert_nil result[:metrics]['dtc'][:actual]
    excluded = report([row(1, current_status_name: 'On-Hold')])
    assert_equal 4.0, excluded[:metrics]['total_hours'][:actual]
    assert_equal 4.0, excluded[:breakdown]['excluded']
    assert_empty excluded[:tickets][:sets]['expected']
    archived = report([row(2, current_status_name: 'Archived', extraordinary_reasons: ['Ticket Owner changed'])])
    assert_equal 4.0, archived[:metrics]['total_hours'][:actual]
    assert_equal 4.0, archived[:breakdown]['archived']
    assert_equal [2], archived[:sets]['archived_hours'].map { |entry| entry[:id] }
    assert_equal [2], archived[:sets]['ownership_review'].map { |entry| entry[:id] }
    assert_empty archived[:tickets][:sets]['actual']
    assert_nil archived[:metrics]['efficiency'][:actual]
    ongoing = report([row(3, current_status_name: 'Ongoing')])
    assert_equal 4.0, ongoing[:metrics]['total_hours'][:actual]
    assert_equal 4.0, ongoing[:breakdown]['ongoing']
    assert_equal 0.0, ongoing[:breakdown]['excluded']
    assert_equal [3], ongoing[:sets]['ongoing_hours'].map { |entry| entry[:id] }
    assert_empty ongoing[:tickets][:sets]['expected']
  end

  private

  def report(items, owner = '1', daily: 8, available: true, any: true)
    TicketJourneyPeriodicTime.owner_report(items, owner, @first, @last, @calendar, @settings, daily,
      total_available: available, any_time_available: any)
  end

  def row(id, **options)
    { id: id, owner_id: '1', owner_visible: true, due: @first + 1,
      beginning_open: false, closed_before: false, assigned_on: @first - 10, hotfix: false,
      done: true, delivered_at: @first + 2, status_name: 'Done / Closed', current_open: false,
      created_date: @first - 5, estimate: 10.0, priority: 'Normal', ticket_hours: 8.0,
      time_allowed: true, weight: 5.0, missing_weight: false,
      owner_logs: { '1' => [[@first + 1, 4.0]] }, invalid_logs: {}, invalid_costs: 0 }.merge(options)
  end
end
