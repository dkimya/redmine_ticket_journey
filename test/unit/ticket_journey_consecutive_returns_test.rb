require File.expand_path('../test_helper', __dir__)

class TicketJourneyConsecutiveReturnsTest < ActiveSupport::TestCase
  setup do
    @controller = TicketJourneyController.new
  end

  test 'returns accumulate across progress completion and later stage failures' do
    transitions = [
      transition(1, nil, 'Returned', synthetic: true),
      transition(2, 'Review', 'Returned'),
      transition(3, 'Returned', 'In Progress'),
      transition(4, 'In Progress', 'Review'),
      transition(5, 'Review', 'Returned'),
      transition(6, 'Returned', 'In Progress'),
      transition(7, 'Review', 'Ready to Merge'),
      transition(8, 'Ready to Merge', 'Final Check'),
      transition(9, 'Final Check', 'Done / Closed'),
      transition(10, 'Done / Closed', 'Returned'),
      transition(11, 'Returned', 'Returned')
    ]

    events = @controller.send(:cumulative_return_events, :internal, transitions)

    assert_equal [2, 5, 10], events.map { |event| event[:journal_detail_id] }
    assert_equal [1, 2, 3], events.map { |event| event[:return_number] }
    assert_equal [:C2, :C2, :C5], events.map { |event| event[:counter_key] }
  end

  test 'one history event cannot be counted twice' do
    event = transition(12, 'Final Check', 'Returned')
    events = @controller.send(:cumulative_return_events, :internal, [event, event.dup])

    assert_equal 1, events.size
  end

  test 'return events follow the existing journey family counters' do
    transitions = [transition(1, 'Review', 'Returned'), transition(2, 'Feedback', 'Returned'), transition(3, 'Done / Closed', 'Returned')]

    assert_equal [:C1, :C5], @controller.send(:cumulative_return_events, :task, transitions).map { |event| event[:counter_key] }
    assert_empty @controller.send(:cumulative_return_events, :container, transitions)
    assert_empty @controller.send(:cumulative_return_events, :customer_support, transitions)
  end

  test 'minimum returns defaults to three and accepts only positive integers' do
    [nil, '', '0', '-1', '2.5', 'invalid'].each do |value|
      assert_equal 3, @controller.send(:minimum_returns_param, value)
    end
    assert_equal 1, @controller.send(:minimum_returns_param, '1')
    assert_equal 4, @controller.send(:minimum_returns_param, '4')
  end

  test 'ticket rows combine stages sort by count and include the threshold boundary' do
    issue_type = Struct.new(:id, :tracker)
    tracker = Struct.new(:name).new('Bug')
    issues = [issue_type.new(101, tracker), issue_type.new(102, tracker), issue_type.new(103, tracker)]
    transitions = {
      101 => [transition(1, 'Review', 'Returned'), transition(2, 'Review', 'Returned')],
      102 => [transition(3, 'Review', 'Returned'), transition(4, 'Final Check', 'Returned'), transition(5, 'Done / Closed', 'Returned')],
      103 => []
    }
    rows = @controller.send(:consecutive_return_rows, issues, transitions)

    assert_equal [102, 101], rows.map { |row| row[:issue].id }
    assert_equal 3, rows.first[:total_returns]
    assert_equal 1, rows.first[:counts][:C2]
    assert_equal 1, rows.first[:counts][:C4]
    assert_equal 1, rows.first[:counts][:C5]
    assert_equal transitions[102].last[:changed_at], rows.first[:latest_return_at]
    report = @controller.send(:consecutive_returns_report, issues, transitions, 3)
    assert_equal 2, report[:ticket_count]
    assert_equal [102], report[:rows].map { |row| row[:issue].id }
    assert_empty @controller.send(:consecutive_returns_report, issues, transitions, 4)[:rows]
  end

  private

  def transition(id, from, to, synthetic: false)
    { journal_id: id, journal_detail_id: id, from_status: from, to_status: to,
      changed_at: Time.utc(2026, 9, 24, 0, id), synthetic: synthetic }
  end
end
