require File.expand_path('../test_helper', __dir__)

class TicketJourneyOwnerPerformanceTest < ActiveSupport::TestCase
  setup do
    @controller = TicketJourneyController.new
  end

  test 'delivery row includes period returns for tickets outside total done' do
    row = {
      owner_id: 7,
      owner_value: '7',
      owner: 'Owner',
      metrics: Hash.new { |hash, key| hash[key] = Set.new },
      return_events: [
        { issue_id: 101, code: :r1 },
        { issue_id: 101, code: :r2 },
        { issue_id: 202, code: :r1 }
      ]
    }
    row[:metrics][:total_done] << 101

    result = @controller.send(:owner_performance_delivery_row, row, 1)

    assert_equal 3, result[:total_return_events]
    assert_equal [101, 202], result[:total_return_issue_ids]
    assert_equal 2, result[:returned_tickets][:count]
    assert_equal 2, result.dig(:returns, :r1, :events)
    assert_equal [101, 202], result.dig(:returns, :r1, :issue_ids)
    assert_equal 1, result.dig(:returns, :r2, :events)
  end

  test 'default tracker names cover all ticket owner performance types' do
    tracker_names = TicketJourneyController::OWNER_PERFORMANCE_TRACKER_NAMES

    assert_includes tracker_names, 'Bug'
    assert_includes tracker_names, 'Change Request'
    assert_includes tracker_names, 'Feature'
    assert_includes tracker_names, 'Task'
    assert_includes tracker_names, 'User Story'
  end

  test 'default status exclusions match ticket owner performance requirements' do
    assert_equal(
      ['New', 'On-Hold', 'Ongoing', 'Archived'],
      TicketJourneyController::OWNER_PERFORMANCE_EXCLUDED_STATUS_NAMES
    )
  end
end
