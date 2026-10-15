require File.expand_path('../test_helper', __dir__)

class PerformanceDashboardColumnsTest < ActionView::TestCase
  tests PerformanceDashboardHelper

  test 'spent time never reveals aggregated hours without time-view permission' do
    project = stub('project')
    issue = stub(id: 1, project: project)
    user = stub('user')
    User.stubs(:current).returns(user)
    user.stubs(:allowed_to?).with(:view_time_entries, project).returns(false)
    @detail_spent_hours = { 1 => 42.5 }
    assert_equal 'Unavailable', performance_detail_cell('spent', {}, issue)
    user.stubs(:allowed_to?).with(:view_time_entries, project).returns(true)
    assert_equal '42.50 h', performance_detail_cell('spent', {}, issue)
    @detail_spent_hours = {}
    assert_equal '0.00 h', performance_detail_cell('spent', {}, issue)
  end

  test 'estimate keeps missing values distinct from a recorded zero' do
    assert_equal 'Not set', performance_detail_cell('estimate', {}, stub(estimated_hours: nil))
    assert_equal '0.00 h', performance_detail_cell('estimate', {}, stub(estimated_hours: 0))
    assert_not_includes TicketJourneyPerformance::DEFAULT_DETAIL_COLUMNS, 'spent'
    assert_includes TicketJourneyPerformance::DETAIL_COLUMNS.keys, 'priority'
  end
end
