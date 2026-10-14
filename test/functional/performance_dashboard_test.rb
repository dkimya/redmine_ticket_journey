require File.expand_path('../test_helper', __dir__)

class PerformanceDashboardTest < ActionController::TestCase
  tests PerformanceDashboardController
  fixtures :all

  setup do
    @request.session[:user_id] = 1
    @project = Project.find(1)
    @project.enabled_module_names = @project.enabled_module_names | ['ticket_journey']
  end

  test 'empty page renders filters without inventing owner totals' do
    Issue.expects(:visible).returns(Issue.none)
    get :index, params: { project_id: @project.identifier }
    assert_response :success
    assert_select '#owner_id'
    assert_select '.nodata', text: /Select a Ticket Owner/
  end

  test 'invalid dates are rejected' do
    get :index, params: { project_id: @project.identifier, as_of: 'not-a-date' }
    assert_response 422
  end

  test 'selected owner renders metrics and missing configuration explanations' do
    issue = Issue.find(1)
    issue.tracker.update!(name: 'Bug')
    Issue.expects(:visible).returns(Issue.where(id: issue.id))
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57))])
    TicketJourneyPerformance.stubs(:snapshot).returns({ id: issue.id, owner_id: '1',
      due: Date.current, open: true, done: false, started: false,
      delivered_at: nil, weight: 5.0, missing_weight: false })
    Setting.plugin_redmine_ticket_journey = { 'performance_start_date' => '', 'performance_count_field_id' => '', 'performance_weight_field_id' => '' }
    get :index, params: { project_id: @project.identifier, owner_id: '1' }
    assert_response :success
    assert_select '.performance-card', count: 4
    assert_select '.performance-metric', text: /Target: Not configured/
    assert_select '.performance-unavailable', text: /configure Day 0/, count: 2
  end

  test 'future dates are rejected' do
    get :index, params: { project_id: @project.identifier, as_of: (Date.current + 1).iso8601 }
    assert_response 422
  end

  test 'monthly targets reject private fields for non administrators' do
    user = User.find(2)
    User.stubs(:current).returns(user)
    field = stub(field_format: 'int', visible?: false)
    UserCustomField.expects(:find_by).with(id: 100).returns(field)
    assert_nil @controller.send(:monthly_target, '100')
  end
end
