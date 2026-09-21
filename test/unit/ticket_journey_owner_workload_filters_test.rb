require File.expand_path('../test_helper', __dir__)

class TicketJourneyOwnerWorkloadFiltersTest < ActiveSupport::TestCase
  include TicketJourneyHelper

  setup do
    statuses = mock('open statuses')
    statuses.stubs(:pluck).with(:id).returns([1, 2, 3, 4])
    IssueStatus.stubs(:where).with(is_closed: false).returns(statuses)
  end

  test 'without due date link retains selected statuses and other report filters' do
    @query = mock('query')
    @query.stubs(:as_params).returns(
      'f' => ['status_id', 'tracker_id'],
      'op' => { 'status_id' => '=', 'tracker_id' => '=' },
      'v' => { 'status_id' => ['2', '3', '9'], 'tracker_id' => ['16'] }
    )

    result = owner_workload_issue_filter_params({ owner_value: '1373' }, :no_due_date)

    assert_equal '=', result['op']['status_id']
    assert_equal ['2', '3'], result['v']['status_id']
    assert_equal ['16'], result['v']['tracker_id']
    assert_equal ['1373'], result['v']['cf_57']
    assert_equal '!*', result['op']['due_date']
  end

  test 'excluded statuses are not reintroduced by open-only drilldowns' do
    assert_equal ['2', '3'], owner_workload_drilldown_status_ids(
      { 'status_id' => '!' }, { 'status_id' => ['1', '4'] }
    )
  end

  test 'closed-only report produces an empty drilldown status set' do
    assert_empty owner_workload_drilldown_status_ids({ 'status_id' => 'c' }, {})
  end
end
