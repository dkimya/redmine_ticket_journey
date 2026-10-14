require File.expand_path('../test_helper', __dir__)
require 'csv'

class TicketJourneyTimeReportPageTest < ActionController::TestCase
  tests TicketJourneyController
  fixtures :all

  setup do
    @request.session[:user_id] = 1
    @issue = Issue.find(1)
    @project = @issue.project
    @project.enabled_module_names = @project.enabled_module_names | ['ticket_journey']
    @controller.stubs(:compute_all_durations).returns([{ issue: @issue, durations: { TOTAL: 0 } }])
    @controller.stubs(:build_report_sections).returns([])
    @activity = @project.activities.first
    TimeEntry.where(issue_id: @issue.id).delete_all
    @entry = TimeEntry.create!(project: @project, issue: @issue, user: User.find(1), author: User.find(1),
                               activity: @activity, spent_on: Date.new(2001, 1, 1), hours: 4)
    @issue.update_column(:estimated_hours, 2)
  end

  test 'time table renders selected activity and current estimate ratio' do
    get :index, params: { project_id: @project.identifier, time_activity_id: @activity.id,
                          set_filter: '1', c: ['id', 'subject'] }
    assert_response :success
    assert_select '#tickets-time-report', count: 1
    assert_select '#time_activity_id[form="query_form"] option[selected]', text: @activity.name
    assert_select '#tickets-time-report tbody td', text: '4.00 h'
    assert_select '#tickets-time-report tbody td', text: '200.0%'
    assert_select '#tickets-time-report tfoot', text: /Total \(1 tickets\)/
  end

  test 'CSV uses the same rows activity and totals as the table' do
    get :index, params: { project_id: @project.identifier, format: 'csv', time_report_export: '1',
                          time_activity_id: @activity.id, set_filter: '1', c: ['id', 'subject'] }
    assert_response :success
    rows = CSV.parse(@response.body)
    assert_includes rows.first.last, @activity.name
    assert_equal @issue.id.to_s, rows[1][0]
    assert_equal ['2.0', '4.0', '200.0', '4.0'], rows[1].last(4)
    assert_equal 'Total', rows[2][0]
    assert_equal rows[1].last(5), rows[2].last(5)
  end

  test 'time entry visibility is applied before aggregation' do
    # A hidden entry must not influence either total or selected-activity hours.
    TimeEntry.expects(:visible).with(User.current).returns(TimeEntry.none)
    @controller.instance_variable_set(:@issues_data, [{ issue: @issue }])
    @controller.instance_variable_set(:@project, @project)
    @controller.params = ActionController::Parameters.new(time_activity_id: @activity.id)
    @controller.send(:prepare_ticket_time_report)
    report = @controller.instance_variable_get(:@ticket_time_report)
    assert report[:rows].all? { |row| row[:spent].nil? || row[:spent].zero? }
    assert report[:rows].all? { |row| row[:activity_spent].nil? || row[:activity_spent].zero? }
  end
end
