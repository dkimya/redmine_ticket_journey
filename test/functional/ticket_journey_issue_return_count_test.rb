require File.expand_path('../test_helper', __dir__)
require 'csv'

class TicketJourneyIssueReturnCountTest < ActionController::TestCase
  tests IssuesController
  fixtures :all

  test 'normal issue page displays the read-only Return Count field' do
    @request.session[:user_id] = 1
    issue = Issue.find(1)
    get :show, params: { id: issue.id }

    assert_response :success
    assert_select '.tj-return-count .label', text: /Return Count/
    assert_select '.tj-return-count .value', text: issue.tj_return_count.to_s
    assert_select 'input[name="issue[tj_return_count]"]', count: 0
  end

  test 'standard CSV export includes Return Count when selected' do
    @request.session[:user_id] = 1
    issue = Issue.find(1)
    get :index, params: {
      project_id: issue.project.identifier, format: 'csv', set_filter: '1',
      f: ['status_id', 'issue_id'], op: { status_id: '*', issue_id: '=' },
      v: { status_id: [''], issue_id: [issue.id.to_s] }, c: ['id', 'tj_return_count']
    }

    assert_response :success
    rows = CSV.parse(@response.body)
    assert_equal 'Return Count', rows.first.last
    assert_equal issue.tj_return_count.to_s, rows.last.last
  end
end
