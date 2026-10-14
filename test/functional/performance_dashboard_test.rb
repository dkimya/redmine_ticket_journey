require File.expand_path('../test_helper', __dir__)

class PerformanceDashboardTest < ActionController::TestCase
  tests PerformanceDashboardController
  fixtures :all

  setup do
    @request.session[:user_id] = 1
    @project = Project.find(1)
    @project.enabled_module_names = @project.enabled_module_names | ['ticket_journey']
  end

  test 'initial page renders filters without loading issues or calculating history' do
    Issue.expects(:visible).never
    TicketJourneyPerformance.expects(:snapshot).never
    TicketJourneyPerformance.expects(:calculate).never
    get :index, params: { project_id: @project.identifier }
    assert_response :success
    assert_select '#owner_id'
    assert_select '.nodata', text: /Select a Ticket Owner/
    assert_select '.performance-card', count: 0
  end

  test 'invalid dates are rejected' do
    get :index, params: { project_id: @project.identifier, as_of: 'not-a-date' }
    assert_response 422
  end

  test 'inactive project members do not appear on initial owner selector' do
    user = User.find(2)
    Member.create!(project: @project, principal: user, roles: [Role.find(1)]) unless Member.exists?(project_id: @project.id, user_id: user.id)
    user.update_column(:status, Principal::STATUS_LOCKED)
    Issue.expects(:visible).never
    get :index, params: { project_id: @project.identifier }
    assert_response :success
    assert_select '#owner_id option[value=?]', user.id.to_s, count: 0
  end

  test 'inactive owner links work without adding the owner to the dropdown' do
    user = User.find(2)
    user.update_column(:status, Principal::STATUS_LOCKED)
    issue = Issue.find(1)
    issue.tracker.update!(name: 'Bug')
    Issue.expects(:visible).at_least_once.returns(Issue.where(id: issue.id))
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57))])
    TicketJourneyPerformance.stubs(:snapshot).returns({ id: issue.id, owner_id: user.id.to_s, status_name: 'In Progress',
      due: Date.current - 30, open: true, done: false, started: true,
      delivered_at: nil, weight: 5.0, missing_weight: false })
    [nil, 'open'].each do |metric|
      get :index, params: { project_id: @project.identifier, owner_id: user.id, metric: metric, as_of: (Date.current - 30).iso8601 }
      assert_response :success
      assert_select '#owner_id option[value=?]', user.id.to_s, count: 0
      if metric
        assert_select 'tbody tr', count: 1
      else
        assert_select '.performance-card', count: 4
        assert_select 'p', text: /Showing report for.*inactive/
      end
    end
  end

  test 'selected owner renders metrics and missing configuration explanations' do
    issue = Issue.find(1)
    issue.tracker.update!(name: 'Bug')
    Issue.expects(:visible).at_least_once.returns(Issue.where(id: issue.id))
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57))])
    TicketJourneyPerformance.stubs(:snapshot).returns({ id: issue.id, owner_id: '1',
      due: Date.current, open: true, done: false, started: false,
      delivered_at: nil, weight: 5.0, missing_weight: false })
    Setting.plugin_redmine_ticket_journey = { 'performance_start_date' => '', 'performance_count_field_id' => '', 'performance_weight_field_id' => '' }
    get :index, params: { project_id: @project.identifier, owner_id: '1' }
    assert_response :success
    assert_select '.performance-card', count: 4
    assert_select '.performance-card-0 .performance-secondary', text: /Stopped:/
    assert_select '.performance-card-0 a[href*="metric=stopped"]', count: 1
    assert_select '.performance-ratios .performance-metric p', text: /Target: 90%/, count: 2
    assert_select '.performance-unavailable', text: /configure Day 0/, count: 2
    Setting.plugin_redmine_ticket_journey = { 'performance_delivery_target' => '92.5' }
    get :index, params: { project_id: @project.identifier, owner_id: '1' }
    assert_response :success
    assert_select '.performance-ratios .performance-metric p', text: /Target: 92.5%/, count: 2
  end

  test 'future dates are rejected' do
    get :index, params: { project_id: @project.identifier, as_of: (Date.current + 1).iso8601 }
    assert_response 422
  end

  test 'unknown drill down is rejected before loading issues' do
    Issue.expects(:visible).never
    get :index, params: { project_id: @project.identifier, metric: 'arbitrary' }
    assert_response :not_found
  end

  test 'drill down uses snapshot status and preserves filters in return link' do
    issue = Issue.find(1)
    issue.tracker.update!(name: 'Bug')
    date = Date.current - 2
    Issue.expects(:visible).at_least_once.returns(Issue.where(id: issue.id))
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57))])
    TicketJourneyPerformance.stubs(:snapshot).returns({ id: issue.id, owner_id: '1', status_name: 'Historical Review',
      due: date - 1, open: true, done: false, started: true,
      delivered_at: nil, weight: 5.0, missing_weight: false })
    get :index, params: { project_id: @project.identifier, owner_id: '1', as_of: date.iso8601, metric: 'started' }
    assert_response :success
    assert_select 'tbody tr', count: 1
    assert_select 'td', text: 'Historical Review'
    assert_select 'a[href=?]', issue_path(issue), text: "##{issue.id}"
    assert_select 'a[href=?]', performance_dashboard_path(@project, owner_id: 1, as_of: date.iso8601), text: /Back to Performance/
  end

  test 'drill down cannot disclose an owner without visible matching issues' do
    Issue.expects(:visible).returns(Issue.none)
    get :index, params: { project_id: @project.identifier, owner_id: '1', metric: 'open' }
    assert_response :not_found
  end

  test 'monthly targets reject private fields for non administrators' do
    user = User.find(2)
    User.stubs(:current).returns(user)
    field = stub(field_format: 'int', visible?: false)
    UserCustomField.expects(:find_by).with(id: 100).returns(field)
    assert_nil @controller.send(:monthly_target, '100')
  end

  test 'hierarchy includes grandchildren but excludes unrelated and invisible projects' do
    root = Project.create!(name: 'Performance root', identifier: 'performance-root', is_public: true)
    child = Project.create!(name: 'Performance child', identifier: 'performance-child', parent: root, is_public: true)
    grandchild = Project.create!(name: 'Performance grandchild', identifier: 'performance-grandchild', parent: child, is_public: true)
    hidden = Project.create!(name: 'Performance hidden', identifier: 'performance-hidden', parent: root, is_public: false)
    outsider = Project.create!(name: 'Performance outside', identifier: 'performance-outside', is_public: true)
    @controller.instance_variable_set(:@project, root.reload)
    User.stubs(:current).returns(User.anonymous)
    ids = @controller.send(:performance_project_ids).pluck(:id)
    assert_equal [root.id, child.id, grandchild.id].sort, ids.sort
    assert_not_includes ids, hidden.id
    assert_not_includes ids, outsider.id
  end

  test 'parent drill down includes nested project ticket and project link exactly once' do
    child = Project.create!(name: 'Performance child', identifier: 'performance-test-child', parent: @project)
    grandchild = Project.create!(name: 'Performance nested', identifier: 'performance-test-nested', parent: child)
    issue = Issue.find(1)
    issue.tracker.update!(name: 'Bug')
    issue.update_columns(project_id: grandchild.id)
    Issue.expects(:visible).at_least_once.returns(Issue.where(id: issue.id))
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57))])
    TicketJourneyPerformance.stubs(:snapshot).returns({ id: issue.id, owner_id: '1', status_name: 'In Progress',
      due: Date.current, open: true, done: false, started: true,
      delivered_at: nil, weight: 5.0, missing_weight: false })
    get :index, params: { project_id: @project.identifier, owner_id: '1', metric: 'open' }
    assert_response :success
    assert_select 'tbody tr', count: 1
    assert_select 'a[href=?]', project_path(grandchild), text: grandchild.name
    assert_select 'a[href=?]', issue_path(issue), count: 1
  end

  test 'initial selector includes a child-only member once without scanning issues' do
    child = Project.create!(name: 'Performance member child', identifier: 'performance-member-child', parent: @project)
    user = User.find(2)
    Member.where(project_id: @project.id, user_id: user.id).destroy_all
    Member.create!(project: child, principal: user, roles: [Role.find(1)])
    Issue.expects(:visible).never
    get :index, params: { project_id: @project.identifier }
    assert_response :success
    assert_select '#owner_id option[value=?]', user.id.to_s, count: 1
  end
end
