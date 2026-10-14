require File.expand_path('../test_helper', __dir__)

class TicketJourneyTimeReportTest < ActiveSupport::TestCase
  setup do
    @controller = TicketJourneyController.new
    @issue_type = Struct.new(:id, :project_id, :estimated_hours, :visible_custom_field_values)
    field = Struct.new(:id).new(56)
    @dev_value = Struct.new(:custom_field, :value).new(field, '8,5')
  end

  test 'activity selection preserves lifetime totals and ratio uses only eligible distinct tickets' do
    issues = [
      @issue_type.new(1, 1, 10, [@dev_value]),
      @issue_type.new(2, 1, 30, []),
      @issue_type.new(3, 1, 0, []),
      @issue_type.new(4, 2, 10, [])
    ]
    hours = { [1, 10] => 5, [1, 11] => 15, [2, 10] => 15, [3, 10] => 100, [4, 10] => 999 }
    report = @controller.send(:build_ticket_time_report, issues + [issues.first], hours, 10, Set[1])

    assert_equal 4, report[:rows].size
    assert_equal 8.5, report[:rows].first[:dev_estimate]
    assert_equal 200.0, report[:rows][0][:ratio]
    assert_equal 50.0, report[:rows][1][:ratio]
    assert_nil report[:rows][2][:ratio]
    assert_nil report[:rows][3][:spent]
    assert_nil report[:rows][3][:activity_spent]
    assert_equal 135.0, report[:totals][:spent]
    assert_equal 120.0, report[:totals][:activity_spent]
    assert_equal 87.5, report[:totals][:ratio]
    assert_equal 2, report[:ratio_excluded]
    assert_equal 1, report[:hidden_time]
    assert_equal 1, report[:missing_pm]

    all = @controller.send(:build_ticket_time_report, issues, hours, nil, Set[1])
    assert_equal all[:totals][:spent], all[:totals][:activity_spent]
    assert_equal report[:totals][:ratio], all[:totals][:ratio]
  end

  test 'empty and unavailable estimates never divide by zero or become false zeros' do
    [nil, '', 'invalid', '5junk', 'NaN', 'Infinity', 0, -2].each do |value|
      assert_nil @controller.send(:ticket_time_estimate, value)
    end
    issue = @issue_type.new(1, 1, nil, [])
    report = @controller.send(:build_ticket_time_report, [issue], {}, nil, Set[1])
    assert_equal 0.0, report[:rows].first[:spent]
    assert_nil report[:totals][:pm_estimate]
    assert_nil report[:totals][:ratio]
    assert_equal 1, report[:ratio_excluded]
    empty = @controller.send(:build_ticket_time_report, [], {}, nil, Set.new)
    assert_empty empty[:rows]
    assert_nil empty[:totals][:ratio]
  end
end
