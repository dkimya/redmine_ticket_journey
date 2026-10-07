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

  test 'combined additional activity excludes time logged under another owner' do
    rows = {
      '7' => { metrics: { spent_time_tickets: Set[101, 102], updated_tickets: Set[101] } },
      '8' => { metrics: { spent_time_tickets: Set.new, updated_tickets: Set[102, 103] } }
    }
    global = { spent_time_tickets: Set[101, 102], updated_tickets: Set[101, 102, 103] }

    @controller.send(:owner_performance_finalize_activity, rows, global)

    assert_equal Set[102, 103], rows['8'][:metrics][:additional_updated_tickets]
    assert_equal Set[103], global[:additional_updated_tickets]
    assert_equal Set[101, 102, 103], global[:total_worked_tickets]
    assert_empty global[:spent_time_tickets] & global[:additional_updated_tickets]
    assert_equal global[:total_worked_tickets].size,
                 global[:spent_time_tickets].size + global[:additional_updated_tickets].size
  end

  test 'default status exclusions match ticket owner performance requirements' do
    assert_equal(
      ['New', 'On-Hold', 'Ongoing', 'Archived'],
      TicketJourneyController::OWNER_PERFORMANCE_EXCLUDED_STATUS_NAMES
    )
  end

  test 'past reports use current due dates for all commitment and debt buckets' do
    start_date = Date.new(2026, 9, 10)
    end_date = Date.new(2026, 9, 30)
    issue_type = Struct.new(:id, :due_date, :created_on, :status, :closed_on)
    status_type = Struct.new(:is_closed?)
    created_on = Time.utc(2026, 9, 1)
    issues = [
      issue_type.new(101, Date.new(2026, 10, 10), created_on, status_type.new(false)),
      issue_type.new(102, Date.new(2026, 9, 5), created_on, status_type.new(false)),
      issue_type.new(103, Date.new(2026, 9, 20), created_on, status_type.new(false)),
      issue_type.new(104, nil, created_on, status_type.new(false)),
      issue_type.new(105, Date.new(2026, 9, 20), created_on, status_type.new(true)),
      issue_type.new(106, Date.new(2026, 9, 20), created_on, status_type.new(true))
    ]
    done_at = Time.utc(2026, 9, 25, 12)
    transitions = { 106 => [{ synthetic: false, from_status: 'Final Check', to_status: 'Done / Closed', changed_at: done_at }] }

    query = mock('query')
    query.stubs(:valid?).returns(true)
    @controller.instance_variable_set(:@query, query)
    @controller.params = ActionController::Parameters.new
    @controller.stubs(:owner_performance_issues).returns(issues)
    @controller.stubs(:load_transitions).returns(transitions)
    @controller.stubs(:load_attribute_changes).with(issues.map(&:id), 'status_id').returns({})
    # Historical deadlines must not be queried, even when a current date is missing.
    @controller.expects(:load_attribute_changes).with(issues.map(&:id), 'due_date').never
    @controller.stubs(:load_custom_field_changes).returns({})
    closed_statuses = mock('closed statuses')
    closed_statuses.stubs(:pluck).with(:id).returns([9])
    IssueStatus.stubs(:where).with(is_closed: true).returns(closed_statuses)
    @controller.stubs(:ticket_owner_values_for_role).returns(nil)
    @controller.stubs(:owner_performance_owner_value_at).returns('7')
    @controller.stubs(:ticket_owner_display_name).returns('Historical Owner')
    @controller.stubs(:historically_closed?).returns(false)
    @controller.stubs(:historically_closed?).with(issues[4], nil, anything, Set['9']).returns(true)
    @controller.stubs(:historically_closed?).with(issues[5], nil, end_date.end_of_day, Set['9']).returns(true)
    @controller.stubs(:time_utilization_entries).returns([])
    @controller.stubs(:owner_performance_period_journals).returns([])
    @controller.stubs(:owner_performance_idle_hours).returns(0.0)
    @controller.stubs(:owner_performance_rework_rows).returns([[], []])
    @controller.stubs(:owner_performance_status_rows).returns([])
    @controller.stubs(:complexity_weight).returns(0.0)
    @controller.stubs(:complexity_weight).with(issues[1]).returns(5.0)
    @controller.stubs(:complexity_weight).with(issues[2]).returns(8.0)
    @controller.stubs(:complexity_weight).with(issues[5]).returns(21.0)

    report = @controller.send(:compute_ticket_owner_performance_report, start_date, end_date,
                              role_id: nil, include_locked_users: true)

    assert_equal [102], report.dig(:commitment, :beginning_total, :issue_ids)
    assert_equal [103, 106], report.dig(:commitment, :new_commitment, :issue_ids)
    assert_equal [102, 103, 106], report.dig(:commitment, :total_commitment, :issue_ids)
    assert_equal [102, 103], report.dig(:completion, :end_debt_total, :issue_ids)
    assert_equal [106], report.dig(:completion, :done_committed, :issue_ids)
    assert_equal [106], report.dig(:completion, :total_done, :issue_ids)
    assert_equal '7', report[:delivery_rows].first[:owner_value]
    assert_equal 34.0, report[:delivery_rows].first.dig(:committed_points, :points)
    assert_equal [102, 103, 106], report[:delivery_rows].first.dig(:committed_points, :issue_ids)
    assert_equal 21.0, report[:delivery_rows].first.dig(:completed_points, :points)
    assert_equal [106], report[:delivery_rows].first.dig(:completed_points, :issue_ids)

    # Rerunning the same past period follows deadline edits made today.
    issues[0].due_date = Date.new(2026, 9, 8)
    issues[2].due_date = nil
    @controller.stubs(:complexity_weight).with(issues[5]).returns(13.0)
    rerun = @controller.send(:compute_ticket_owner_performance_report, start_date, end_date,
                             role_id: nil, include_locked_users: true)

    assert_equal [101, 102], rerun.dig(:commitment, :beginning_total, :issue_ids)
    assert_equal [106], rerun.dig(:commitment, :new_commitment, :issue_ids)
    assert_equal [101, 102], rerun.dig(:completion, :end_debt_total, :issue_ids)
    assert_equal [106], rerun.dig(:completion, :total_done, :issue_ids)
    assert_equal 18.0, rerun[:delivery_rows].first.dig(:committed_points, :points)
    assert_equal [101], rerun[:delivery_rows].first.dig(:committed_points, :missing_issue_ids)
    assert_equal 13.0, rerun[:delivery_rows].first.dig(:completed_points, :points)

    # Other Done is part of completed points even when outside commitment.
    issues[5].due_date = Date.new(2026, 10, 10)
    other_done_report = @controller.send(:compute_ticket_owner_performance_report, start_date, end_date,
                                         role_id: nil, include_locked_users: true)
    assert_equal [106], other_done_report.dig(:completion, :other_done, :issue_ids)
    assert_equal 5.0, other_done_report[:delivery_rows].first.dig(:committed_points, :points)
    assert_equal 13.0, other_done_report[:delivery_rows].first.dig(:completed_points, :points)
  end

  test 'complexity points count distinct tickets once and keep missing weights separate' do
    weights = { 101 => 5.0, 102 => 8.0, 103 => 21.0, 104 => 0.0, 105 => -1.0, 106 => Float::INFINITY }
    result = @controller.send(:owner_performance_points_metric, [101, 102, 101, 103, 104, 105, 106, 107], weights)

    assert_equal 34.0, result[:points]
    assert_equal [101, 102, 103], result[:issue_ids]
    assert_equal [104, 105, 106, 107], result[:missing_issue_ids]
    assert_equal({ points: 0, issue_ids: [], missing_issue_ids: [] },
                 @controller.send(:owner_performance_points_metric, [], weights))
  end

  test 'points columns sort by points rather than ticket count or displayed text' do
    rows = [
      { owner: 'Owner A', committed_points: { points: 8.0 }, completed_points: { points: 21.0 } },
      { owner: 'Owner B', committed_points: { points: 21.0 }, completed_points: { points: 5.0 } }
    ]
    @controller.params = ActionController::Parameters.new(owner_sort: 'committed_points', owner_dir: 'desc')
    assert_equal ['Owner B', 'Owner A'], @controller.send(:sort_owner_performance_delivery_rows, rows).map { |row| row[:owner] }

    @controller.params = ActionController::Parameters.new(owner_sort: 'completed_points', owner_dir: 'asc')
    assert_equal ['Owner B', 'Owner A'], @controller.send(:sort_owner_performance_delivery_rows, rows).map { |row| row[:owner] }
  end
end
