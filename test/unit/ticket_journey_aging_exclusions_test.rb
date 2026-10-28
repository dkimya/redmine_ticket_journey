require File.expand_path('../test_helper', __dir__)

class TicketJourneyAgingExclusionsTest < ActiveSupport::TestCase
  include TicketJourneyHelper
  include ActionView::Helpers::NumberHelper

  setup do
    @controller = TicketJourneyController.new
    @controller.params = ActionController::Parameters.new
    @date = Date.new(2026, 10, 28)
    @normal = ticket('In Progress', 10)
    @ongoing = ticket('Ongoing', 1000)
  end

  test 'Ongoing has no creation development planning or debt age while ordinary tickets retain real ages' do
    assert_nil @controller.send(:ticket_creation_age_days, @ongoing, @date)
    assert_equal 10, @controller.send(:ticket_creation_age_days, @normal, @date)
    %w[development planning end_to_end].each do |calculation|
      assert_nil @controller.send(:aging_start_time, @ongoing, [], calculation)
    end
    assert_nil @controller.send(:executive_debt_age_days, @ongoing, @date)
    assert_equal 5, @controller.send(:executive_debt_age_days, @normal, @date)
    assert_nil @controller.send(:executive_resolved_debt_age_days, { issue: @ongoing, closed_at: @date.in_time_zone })
    assert_equal 5, @controller.send(:executive_resolved_debt_age_days, { issue: @normal, closed_at: @date.in_time_zone })
    assert_equal 'N/A', ticket_age_label(nil)
    assert_equal '0d', ticket_age_label(0)
  end

  test 'workload retains Ongoing counts but removes it from age numerator and denominator' do
    User.stubs(:current).returns(stub(today: @date))
    @controller.instance_variable_set(:@query, stub(valid?: true))
    @controller.stubs(:owner_workload_issues).returns([@normal, @ongoing])
    @controller.stubs(:ticket_owner_values_for_role).returns(nil)
    @controller.stubs(:ticket_owner_info).returns(['1', 'Developer'])
    @controller.stubs(:technical_tracker?).returns(true)
    @controller.stubs(:task_tracker?).returns(false)
    @controller.stubs(:container_tracker?).returns(false)
    @controller.stubs(:paused_status?).returns(false)
    @controller.stubs(:priority_performance_ticket?).returns(false)
    rows, totals = @controller.send(:compute_owner_workload_report)
    assert_equal 2, totals[:total_open]
    assert_equal 1, rows.first[:age_count]
    assert_equal 10.0, rows.first[:avg_age]
    assert_equal 10, rows.first[:oldest_age]
    @controller.stubs(:owner_workload_issues).returns([@ongoing])
    rows, totals = @controller.send(:compute_owner_workload_report)
    assert_equal 1, totals[:total_open]
    assert_nil rows.first[:avg_age]
    assert_nil rows.first[:oldest_age]
  end

  test 'priority aggregates never dilute known ages with excluded or unavailable values' do
    base = { owner_value: '1', owner: 'Developer', overdue: false, stopped: false, no_due_date: false }
    rows = [base.merge(age_days: 10), base.merge(age_days: nil)]
    owners = @controller.send(:priority_owner_rows, rows)
    totals = @controller.send(:priority_risk_totals, rows, owners)
    assert_equal 2, totals[:total_open]
    assert_equal 10.0, totals[:avg_age]
    assert_equal 10, totals[:oldest_age]
    owners = @controller.send(:priority_owner_rows, [rows.last])
    totals = @controller.send(:priority_risk_totals, [rows.last], owners)
    assert_nil owners.first[:oldest_age]
    assert_nil totals[:avg_age]
    assert_nil totals[:oldest_age]
    @controller.instance_variable_set(:@query, stub(issues: [@normal, @ongoing]))
    assert_equal [@normal], @controller.send(:aging_risk_issues)
  end

  private

  def ticket(status, age)
    stub(status: stub(name: status, is_closed?: false), created_on: (@date - age).in_time_zone,
      due_date: @date - 5, tracker: stub(name: 'Bug'))
  end
end
