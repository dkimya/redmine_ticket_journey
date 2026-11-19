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

  private

  def change(id, from, to, actor: nil, reason: nil)
    { id: id, from: from, to: to, user_id: actor, reason: reason }
  end
end
