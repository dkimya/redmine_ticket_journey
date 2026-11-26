require File.expand_path('../test_helper', __dir__)

class TicketJourneyQaReportTest < ActiveSupport::TestCase
  test 'only an explicit False QA Pass charges the preceding pass once' do
    changes = [
      change(1, 'Feedback', 'Review', actor: 3),
      change(2, 'Review', 'Returned', reason: 'Wrong Implementation'),
      change(3, 'Final Check', 'Returned', reason: 'False QA Pass'),
      change(4, 'Feedback', 'Review', actor: 4),
      change(5, 'Final Check', 'Returned', reason: 'False QA Pass'),
      change(6, 'Final Check', 'Returned', reason: 'False QA Pass'),
      change(7, 'Feedback', 'Review', actor: 3),
      change(8, 'Ready to Merge', 'Returned', reason: 'False QA Pass')
    ]

    events = TicketJourneyQaReport.false_passes(changes, reason_visible: true)
    assert_equal [5, 8], events.map { |event| event[:id] }
    assert_equal [4, 3], events.map { |event| event[:pass][:user_id] }
    assert_equal(-8, TicketJourneyQaReport.allocate.send(:penalty, 8, events.first, []))
  end

  test 'missing and hidden reasons stay pending' do
    pass = change(1, 'Feedback', 'Review', actor: 3)
    missing = change(2, 'Final Check', 'Returned')
    hidden = change(2, 'Final Check', 'Returned', reason: 'False QA Pass')
    assert_nil TicketJourneyQaReport.false_passes([pass, missing], reason_visible: true).sole[:reason]
    assert_nil TicketJourneyQaReport.false_passes([pass, hidden], reason_visible: false).sole[:reason]
  end

  test 'same day testing counts as Work and later testing counts as Rework' do
    day = Date.new(2026, 11, 12)
    activity = TicketJourneyQaReport::TEST_ACTIVITY
    entries = [[day - 1, 2.0, activity], [day, 3.0, activity], [day + 1, 4.0, activity],
               [day + 1, 5.0, 'Development']]
    assert_equal({ work: 5.0, rework: 4.0 }, TicketJourneyQaReport.test_time(entries, day.in_time_zone))
  end

  test 'filtering a Bug that was both found and escaped keeps each score with its actor' do
    report = TicketJourneyQaReport.allocate
    report.instance_variable_set(:@tester_ids, Set[4])
    report.instance_variable_set(:@detected_field, stub(id: 76))
    report.instance_variable_set(:@bugs, [])
    row = { issue: stub(author_id: 3), status: 'New', weight: 5 }
    values = { 76 => 'QA', TicketJourneyController::BUG_SOURCE_CF_ID => 'Test Escape' }

    report.send(:add_bug, row, values, 4)
    bug = report.bugs.sole
    assert_equal [false, nil, true, -10], bug.values_at(:qa_find, :credit, :escape, :escape_points)

    report.instance_variable_set(:@tester_ids, Set[3])
    report.bugs.clear
    report.send(:add_bug, row, values, 4)
    assert_equal [true, 5, false, nil], report.bugs.sole.values_at(:qa_find, :credit, :escape, :escape_points)
  end

  test 'gate duration uses recorded entries for each visit and leaves an ongoing visit open' do
    day = Date.new(2026, 11, 12).in_time_zone
    events = [
      change(1, 'New', 'Feedback').merge(at: day),
      change(2, 'Feedback', 'Returned', actor: 3).merge(at: day + 12.hours),
      change(3, 'In Progress', 'Feedback').merge(at: day + 1.day),
      change(4, 'Feedback', 'Review', actor: 3).merge(at: day + 2.days),
      change(5, 'Ready to Merge', 'Final Check').merge(at: day + 3.days)
    ]
    verdicts, waiting = TicketJourneyQaReport.gate_history(events)
    assert_equal [[:returned, 0.5], [:passed, 1.0]], verdicts.map { |row| row.values_at(:outcome, :days) }
    assert_equal({ 'Final Check' => day + 3.days }, waiting)
    assert_nil TicketJourneyQaReport.gate_history([events[1]]).first.sole[:days]
  end

  test 'QA summary weights penalties once and pools a dual-role tester without double counting weight' do
    issue = stub(id: 1, tracker: stub(name: 'Feature'))
    bug = stub(id: 2, tracker: stub(name: 'Bug'))
    processed = { issue: issue, weight: 12.0, status: 'Done / Closed',
      gates: [{ role: 'QA', actor: 3, outcome: :passed, days: 1.0 },
              { role: 'QA-L2', actor: 3, outcome: :returned, days: 2.0 },
              { role: 'QA-L2', actor: 3, outcome: :passed, days: 3.0 }],
      testing: { 3 => { work: 2.0, rework: 1.0 }, 4 => { work: 5.0, rework: 0.0 } } }
    processed[:workflow_gates] = processed[:gates]
    found = { issue: bug, status: 'New', qa_find: true, credit: 57, finder_id: 3, escape: true,
      escape_points: -16, escape_actor: 3 }
    false_pass = { issue: issue, event: { reason: 'False QA Pass', pass: { user_id: 3 } }, points: -32, audit: [] }
    report = stub(dashboard_rows: [processed], queue: [], bugs: [found], returns: [false_pass])
    source = TicketJourneyQaDashboardSummary.new(report)
    summary = source.calculate

    assert_equal 9.0, summary[:points][:total]
    assert_equal [57.0, -32.0, -16.0], summary[:points].values_at(:found, :false_passes, :escapes)
    assert_equal 1, summary[:workflow]['QA'][:tested].size
    assert_equal 1, summary[:workflow]['QA-L2'][:passed].size
    assert_empty summary[:workflow]['QA-L2'][:returned]
    assert_equal 2.0, summary[:duration]
    assert_equal 8.0, summary[:hours][:total]
    assert_equal 4.0, summary[:efficiency]
    assert_equal 3.0, source.calculate(actor: 3)[:hours][:total]
    assert_empty source.calculate(actor: 4)[:workflow]['QA'][:tested]
    assert_nil source.calculate(actor: 4)[:efficiency]
  end

  private

  def change(id, from, to, actor: nil, reason: nil)
    { id: id, from: from, to: to, user_id: actor, reason: reason }
  end
end
