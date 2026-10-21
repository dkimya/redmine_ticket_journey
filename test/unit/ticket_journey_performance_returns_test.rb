require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceReturnsTest < ActiveSupport::TestCase
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

  test 'distributions partition distinct eligible tickets and ratios may exceed 100 percent' do
    rows = [row(1, 0), row(2, 1), row(3, 2, 1), row(4, 3, 2), row(5, 4, 3)]
    report = TicketJourneyPerformanceReturns.calculate(rows + ['New', 'On-Hold', 'Ongoing', 'Archived', 'Done / Closed'].map { |status| row(6, 4, 3, status) })
    assert_equal 5, report[:open]
    assert_equal [1, 1, 1, 1, 1], (0..4).map { |i| report[:sets]["returns_#{i}"].size }
    assert_equal [1, 1, 1], (1..3).map { |i| report[:sets]["repeats_#{i}"].size }
    assert_equal 3, report[:with_repeats]
    assert_equal 200, report[:ratio]
    assert_equal 200, report[:adjusted_ratio]
  end

  test 'missing reasons block adjusted metric but not total distribution and zero populations show N A' do
    report = TicketJourneyPerformanceReturns.calculate([row(1, 2, 1, unknown: true)])
    assert_equal 200, report[:ratio]
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
    assert_equal 300, report[:ratio]
    assert_equal 200, report[:adjusted_ratio]
    assert_equal [ticket], report[:sets]['returns_3']
    assert_equal [ticket], report[:sets]['repeats_2']
    assert_equal [ticket], report[:sets]['non_merge_incidents']
  end
end
