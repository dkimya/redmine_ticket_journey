require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceReturnsTest < ActiveSupport::TestCase
  test 'return types count stages and tied reasons over exact open population' do
    rows = [row(1, 2), row(2, 0), row(3, 1, 0, 'Done / Closed')]
    rows[0][:events] = [
      { counter_key: :C1, reason: 'Fix', merge_conflict: false },
      { counter_key: :C3, reason: 'Merge Conflict', merge_conflict: true }
    ]
    result = TicketJourneyPerformanceReturns.return_types(TicketJourneyPerformanceReturns.calculate(rows))
    assert_equal({ C1: 1, C2: 0, C3: 1, C4: 0, C5: 0 }, result[:stages])
    assert_equal 50.0, result[:rate]
    assert_equal [['Fix', 1], ['Merge Conflict', 1]], result[:top_reasons]
    rows[0][:events][0][:reason] = nil
    result = TicketJourneyPerformanceReturns.return_types(TicketJourneyPerformanceReturns.calculate(rows))
    assert_includes result[:top_reasons], ['Reason unavailable', 1]
    empty = TicketJourneyPerformanceReturns.return_types(TicketJourneyPerformanceReturns.calculate([]))
    assert_nil empty[:rate]
    assert_empty empty[:top_reasons]
  end

  def issue(tracker = 'Bug')
    stub(tracker: stub(name: tracker))
  end

  def statuses
    { '1' => stub(name: 'Feedback'), '2' => stub(name: 'Returned'),
      '3' => stub(name: 'Review '), '4' => stub(name: 'In Progress'),
      '5' => stub(name: 'Final Check') }
  end

  def change(id, date, stage, extra = [])
    TicketJourneyPerformance::HistoryJournal.new(id, date.in_time_zone, [
      TicketJourneyPerformance::HistoryDetail.new('attr', 'status_id', stage, '2', id)
    ] + extra)
  end

  test 'same-stage repeats accumulate across stages and intermediate progress is ignored' do
    date = Date.new(2026, 10, 21)
    history = %w[1 1 1 5 5].each_with_index.map { |stage, index| change(index + 1, date - 6 + index, stage) }
    progress = TicketJourneyPerformance::HistoryJournal.new(20, (date - 3).in_time_zone + 1.hour, [
      TicketJourneyPerformance::HistoryDetail.new('attr', 'status_id', '2', '4', 20)
    ])
    history << progress
    history << change(30, date + 1, '5')
    events = TicketJourneyPerformanceReturns.events_for(issue, history, statuses, date, reason_value: 'Bug', reason_visible: true)
    assert_equal 5, events.size
    assert_equal 3, events.count { |event| event[:repeat] }
    assert_equal [false, true, true, false, true], events.map { |event| event[:repeat] }
  end

  test 'reason is reconstructed at return time including same-journal and future edits' do
    date = Date.new(2026, 10, 21)
    history = [change(1, date - 2, '1'), change(2, date - 1, '1', [
      TicketJourneyPerformance::HistoryDetail.new('cf', '66', 'Bug', 'Merge Conflict', 10)
    ])]
    history << TicketJourneyPerformance::HistoryJournal.new(3, (date + 1).in_time_zone, [
      TicketJourneyPerformance::HistoryDetail.new('cf', '66', 'Merge Conflict', 'Bug', 11)
    ])
    events = TicketJourneyPerformanceReturns.events_for(issue, history, statuses, date, reason_value: 'Bug', reason_visible: true)
    assert_equal ['Bug', 'Merge Conflict'], events.map { |event| event[:reason] }
    assert_equal [false, true], events.map { |event| event[:merge_conflict] }
    hidden = TicketJourneyPerformanceReturns.events_for(issue, history, statuses, date, reason_value: 'Bug', reason_visible: false)
    assert hidden.all? { |event| event[:reason].nil? && event[:merge_conflict].nil? }
  end

  test 'shared qualifying rules keep Task review returns excluded and deduplicate detail IDs' do
    date = Date.new(2026, 10, 21)
    history = [change(1, date, '3'), change(2, date, '1'), change(2, date, '1')]
    events = TicketJourneyPerformanceReturns.events_for(issue('Task (Business Jobs)'), history, statuses, date, reason_value: 'Bug', reason_visible: true)
    assert_equal 1, events.size
    assert_equal :C1, events.first[:counter_key]
  end

  def row(id, count, repeats = 0, status = 'Pending', unknown: false)
    { id: id, open: !['Done / Closed', 'Archived'].include?(status), status_name: status,
      return_count: count, repeat_count: repeats,
      events: Array.new(count) { { merge_conflict: unknown ? nil : false } } }
  end

  test 'trend uses five completed calendar month ends across years and leap years' do
    assert_equal [Date.new(2025, 8, 31), Date.new(2025, 9, 30), Date.new(2025, 10, 31), Date.new(2025, 11, 30), Date.new(2025, 12, 31)],
      TicketJourneyPerformanceReturns.trend_points(Date.new(2026, 1, 15)).map { |point| point[:date] }
    assert_equal [Date.new(2023, 10, 31), Date.new(2023, 11, 30), Date.new(2023, 12, 31), Date.new(2024, 1, 31), Date.new(2024, 2, 29)],
      TicketJourneyPerformanceReturns.trend_points(Date.new(2024, 3, 1)).map { |point| point[:date] }
  end

  test 'trend reconstructs closed status while attributing every month to current owner' do
    date = Date.new(2026, 10, 21)
    ticket = stub(id: 1, tracker: stub(name: 'Bug'), created_on: Date.new(2026, 7, 1).in_time_zone,
      status_id: 3, due_date: nil, start_date: nil)
    states = { '1' => stub(name: 'Feedback', is_closed: false),
      '2' => stub(name: 'Returned', is_closed: false), '3' => stub(name: 'Done / Closed', is_closed: true) }
    history = [change(1, Date.new(2026, 7, 10), '1'), change(2, Date.new(2026, 8, 10), '1'),
      TicketJourneyPerformance::HistoryJournal.new(3, Date.new(2026, 9, 5).in_time_zone, [
        TicketJourneyPerformance::HistoryDetail.new('cf', '57', '10', '20', 3)
      ]),
      TicketJourneyPerformance::HistoryJournal.new(4, Date.new(2026, 10, 5).in_time_zone, [
        TicketJourneyPerformance::HistoryDetail.new('attr', 'status_id', '2', '3', 4)
      ])]
    values = [TicketJourneyPerformance::FieldValue.new(stub(id: 57), '20'),
      TicketJourneyPerformance::FieldValue.new(stub(id: 66), 'Bug')]
    points = TicketJourneyPerformanceReturns.trend_points(date).last(3)
    TicketJourneyPerformanceReturns.accumulate_trend!(points, ticket, history, states, date, values, Set['20'])
    TicketJourneyPerformanceReturns.finish_trend!(points)
    assert_equal [1, 1, 1], points.map { |point| point[:open] }
    assert_equal [1, 2, 2], points.map { |point| point[:incidents] }
    assert_equal [1.0, 2.0, 2.0], points.map { |point| point[:ratio] }
    assert_equal [1, 1, 1], points.map { |point| point[:returned] }
    assert_equal [1.0, 2.0, 2.0], points.map { |point| point[:adjusted_ratio] }
    combined = TicketJourneyPerformanceReturns.trend_points(date).last(3)
    TicketJourneyPerformanceReturns.accumulate_trend!(combined, ticket, history, states, date, values, Set['10', '20'])
    assert_equal [1, 1, 1], combined.map { |point| point[:open] }
    assert_equal [1, 2, 2], combined.map { |point| point[:incidents] }
    previous_owner = TicketJourneyPerformanceReturns.trend_points(date).last(3)
    TicketJourneyPerformanceReturns.accumulate_trend!(previous_owner, ticket, history, states, date, values, Set['10'])
    assert previous_owner.all? { |point| point[:open].zero? }
    individual = { '10' => TicketJourneyPerformanceReturns.trend_points(date).last(3),
                   '20' => TicketJourneyPerformanceReturns.trend_points(date).last(3) }
    team = TicketJourneyPerformanceReturns.trend_points(date).last(3)
    counted_events = TicketJourneyPerformanceReturns.events_for(ticket, history, states, date, reason_value: 'Bug', reason_visible: true)
    TicketJourneyPerformanceReturns.expects(:events_for).once.returns(counted_events)
    TicketJourneyPerformanceReturns.accumulate_trend!(team, ticket, history, states, date, values, Set['10', '20'], owner_points: individual)
    TicketJourneyPerformanceReturns.finish_trend!(team)
    individual.each_value { |points| TicketJourneyPerformanceReturns.finish_trend!(points) }
    assert_equal team, individual['20']
    assert individual['10'].all? { |point| point[:open].zero? && point[:ratio].nil? }
  end

  test 'trend excludes tickets before creation and marks hidden reasons unavailable' do
    date = Date.new(2026, 10, 21)
    ticket = stub(id: 1, tracker: stub(name: 'Bug'), created_on: Date.new(2026, 8, 1).in_time_zone,
      status_id: 2, due_date: nil, start_date: nil)
    states = { '1' => stub(name: 'Feedback', is_closed: false), '2' => stub(name: 'Returned', is_closed: false) }
    values = [TicketJourneyPerformance::FieldValue.new(stub(id: 57), '10')]
    points = TicketJourneyPerformanceReturns.trend_points(date).last(3)
    TicketJourneyPerformanceReturns.accumulate_trend!(points, ticket, [change(1, Date.new(2026, 8, 15), '1')], states, date, values, Set['10'])
    TicketJourneyPerformanceReturns.finish_trend!(points)
    assert_equal [0, 1, 1], points.map { |point| point[:open] }
    assert_equal [nil, 1.0, 1.0], points.map { |point| point[:ratio] }
    assert_equal [nil, nil, nil], points.map { |point| point[:adjusted_ratio] }
    assert_equal [0, 1, 1], points.map { |point| point[:unknown] }
  end

  test 'trend applies merge exclusion and sums counts before calculating multi owner ratios' do
    date = Date.new(2026, 10, 21)
    points = TicketJourneyPerformanceReturns.trend_points(date).last(3)
    states = { '1' => stub(name: 'Feedback', is_closed: false), '2' => stub(name: 'Returned', is_closed: false) }
    [0, 1, 2].each do |index|
      ticket = stub(id: index + 1, tracker: stub(name: 'Bug'), created_on: Date.new(2026, 6, 1).in_time_zone,
        status_id: 2, due_date: nil, start_date: nil)
      values = [TicketJourneyPerformance::FieldValue.new(stub(id: 57), index.zero? ? '10' : '20'),
        TicketJourneyPerformance::FieldValue.new(stub(id: 66), index.zero? ? 'Merge Conflict' : 'Bug')]
      history = index < 2 ? [change(index + 1, Date.new(2026, 7, 15), '1')] : []
      TicketJourneyPerformanceReturns.accumulate_trend!(points, ticket, history, states, date, values, Set['10', '20'])
    end
    TicketJourneyPerformanceReturns.finish_trend!(points)
    points.each do |point|
      assert_equal 3, point[:open]
      assert_equal 2, point[:incidents]
      assert_equal 1, point[:non_merge]
      assert_equal 2, point[:returned]
      assert_equal 1.0, point[:ratio]
      assert_equal 0.5, point[:adjusted_ratio]
    end
  end

  test 'distributions partition eligible tickets while metric averages incidents over returned tickets only' do
    rows = [row(1, 0), row(2, 1), row(3, 2, 1), row(4, 3, 2), row(5, 4, 3)]
    report = TicketJourneyPerformanceReturns.calculate(rows + ['New', 'On-Hold', 'Archived', 'Done / Closed'].map { |status| row(6, 4, 3, status) })
    assert_equal 5, report[:open]
    assert_equal [1, 1, 1, 1, 1], (0..4).map { |i| report[:sets]["returns_#{i}"].size }
    assert_equal [1, 1, 1], (1..3).map { |i| report[:sets]["repeats_#{i}"].size }
    assert_equal 3, report[:with_repeats]
    assert_equal 4, report[:returned]
    assert_equal 2.5, report[:ratio]
    assert_equal 2.5, report[:adjusted_ratio]
  end

  test 'Ongoing shares Tickets open denominator and is included in all Returns populations' do
    ongoing = row(1, 0, 0, 'Ongoing')
    returned = row(2, 2, 1)
    rows = [ongoing, returned]
    report = TicketJourneyPerformanceReturns.calculate(rows)
    assert_equal 2, report[:open]
    assert_equal [ongoing], report[:sets]['returns_0']
    assert_equal 1, report[:returned]
    assert_equal 2.0, report[:ratio]
    assert_equal 2.0, report[:adjusted_ratio]
    ticket_report = TicketJourneyPerformance.calculate(rows, Date.new(2026, 10, 21))
    assert_equal ticket_report[:groups].first.map { |ticket| ticket[:id] }, report[:sets]['returns_open'].map { |ticket| ticket[:id] }
    ongoing_with_history = row(3, 2, 1, 'Ongoing')
    included = TicketJourneyPerformanceReturns.calculate([ongoing_with_history])
    assert_equal [ongoing_with_history], included[:sets]['returns_2']
    assert_equal [ongoing_with_history], included[:sets]['repeats_1']
    assert_equal [ongoing_with_history], included[:sets]['return_incidents']
    assert_equal [ongoing_with_history], included[:sets]['non_merge_incidents']
    assert_same TicketJourneyPerformance::OPEN_EXCLUDED_STATUSES, TicketJourneyPerformanceReturns::EXCLUDED
  end

  test 'missing reasons block adjusted metric but not total distribution and zero populations show N A' do
    report = TicketJourneyPerformanceReturns.calculate([row(1, 2, 1, unknown: true)])
    assert_equal 2.0, report[:ratio]
    assert_nil report[:adjusted_ratio]
    assert_equal 2, report[:unknown]
    empty = TicketJourneyPerformanceReturns.calculate([])
    assert_nil empty[:ratio]
    assert_nil empty[:adjusted_ratio]
  end

  test 'merge conflict is excluded only from adjusted incidents not distributions or repeats' do
    ticket = row(1, 3, 2)
    ticket[:events] = [{ merge_conflict: false }, { merge_conflict: true }, { merge_conflict: false }]
    report = TicketJourneyPerformanceReturns.calculate([ticket])
    assert_equal 3, report[:incidents]
    assert_equal 3.0, report[:ratio]
    assert_equal 2.0, report[:adjusted_ratio]
    assert_equal [ticket], report[:sets]['returns_3']
    assert_equal [ticket], report[:sets]['repeats_2']
    assert_equal [ticket], report[:sets]['non_merge_incidents']
  end

  test 'no returns differs from empty population and duplicate rows cannot inflate the metric' do
    no_returns = TicketJourneyPerformanceReturns.calculate([row(1, 0), row(2, 0)])
    assert_equal 2, no_returns[:open]
    assert_equal 0, no_returns[:returned]
    assert_equal 0, no_returns[:incidents]
    assert_nil no_returns[:ratio]
    assert_nil no_returns[:adjusted_ratio]
    ticket = row(3, 2)
    report = TicketJourneyPerformanceReturns.calculate([ticket, ticket, row(4, 0)])
    assert_equal 2, report[:open]
    assert_equal 1, report[:returned]
    assert_equal 2.0, report[:ratio]
  end

  test 'merge-only tickets remain in the denominator and produce a measured zero' do
    merge_only = row(1, 2, 1)
    merge_only[:events] = [{ merge_conflict: true }, { merge_conflict: true }]
    non_merge = row(2, 3, 2)
    report = TicketJourneyPerformanceReturns.calculate([merge_only, non_merge, row(3, 0)])
    assert_equal 2, report[:returned]
    assert_equal 3, report[:non_merge]
    assert_equal 1.5, report[:adjusted_ratio]
    assert_equal [merge_only, non_merge], report[:sets]['non_merge_denominator']
    assert_equal [non_merge], report[:sets]['non_merge_incidents']
    zero = TicketJourneyPerformanceReturns.calculate([merge_only])
    assert_equal 0.0, zero[:adjusted_ratio]
    assert_equal 2.0, zero[:ratio]
    assert_equal 1, zero[:with_repeats]
    points = [{ returned: 1, incidents: 2, non_merge: 0, unknown: 0, open: 2 }]
    TicketJourneyPerformanceReturns.finish_trend!(points)
    assert_equal 0.0, points.first[:adjusted_ratio]
  end
end
