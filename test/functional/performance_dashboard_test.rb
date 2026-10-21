require File.expand_path('../test_helper', __dir__)

class PerformanceDashboardTest < ActionController::TestCase
  tests PerformanceDashboardController
  fixtures :all

  setup do
    @request.session[:user_id] = 1
    @project = Project.find(1)
    @project.enabled_module_names = @project.enabled_module_names | ['ticket_journey']
    # These controller/render tests already supply synthetic snapshots. Keep
    # candidate SQL isolated here; real database coverage lives in scan_test.
    @controller.define_singleton_method(:candidate_issues) { |scope, owner_ids| scope }
    @controller.stubs(:discover_owner_ids).returns(Set['1', '2'])
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

  test 'planned time tab preserves context without calculating reports' do
    Issue.expects(:visible).never
    TicketJourneyPerformance.expects(:history_for).never
    TicketJourneyPerformance.expects(:calculate).never
    %w[time].each do |tab|
      get :index, params: { project_id: @project.identifier, tab: tab,
                            owner_ids: ['1', '2'], as_of: Date.current.iso8601 }
      assert_response :success
      assert_select '.performance-planned-section', text: /planned for a later implementation/
      assert_select '.performance-tabs a[aria-current="page"]', text: /#{tab.titleize}/
      assert_select 'input[name="tab"][value=?]', tab
      assert_select '#owner_id option[selected]', count: 2
      assert_select '.performance-card', count: 0
      assert_select '.performance-tabs a', count: 3 do |links|
        links.each do |link|
          context = Rack::Utils.parse_nested_query(URI.parse(link['href']).query)
          assert_equal ['1', '2'], context['owner_ids']
          assert_equal Date.current.iso8601, context['as_of']
          assert_nil context['metric']
        end
      end
    end
  end

  test 'Returns initial page is live without scanning issues before Apply' do
    Issue.expects(:visible).never
    get :index, params: { project_id: @project.identifier, tab: 'returns' }
    assert_response :success
    assert_select '.performance-header h2', text: 'Performance Results — Returns'
    assert_select '.performance-planned-section', count: 0
    assert_select '.nodata', text: /No return report has been calculated/
    assert_select 'input[name="tab"][value="returns"]'
  end

  test 'Returns comparison chart and audit drill down share exact historical population' do
    issue = Issue.find(1)
    issue.tracker.update!(name: 'Bug')
    Issue.expects(:visible).at_least_once.returns(Issue.where(id: issue.id))
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57), value: '1')])
    TicketJourneyPerformance.stubs(:snapshot).returns({ id: issue.id, owner_id: '1', status_name: 'Pending',
      open: true, due: nil, weight: 5.0, missing_weight: false })
    events = [false, true, true].each_with_index.map do |repeat, index|
      { journal_id: index + 1, at: Time.current - index.hours, from_status: 'Feedback', reason: 'Bug', repeat: repeat, merge_conflict: false }
    end
    TicketJourneyPerformanceReturns.stubs(:events_for).returns(events)
    first_month_end = TicketJourneyPerformanceReturns.trend_points(Date.current).first[:date]
    TicketJourneyPerformance.expects(:history_for).with([issue.id], first_month_end, include_return_reason: true).returns({})
    get :index, params: { project_id: @project.identifier, tab: 'returns', owner_id: '1' }
    assert_response :success
    assert_select '.performance-return-owner-row', count: 1
    assert_select '.performance-return-distributions .performance-donut', count: 2
    assert_select '.performance-return-value', text: '300%', count: 2
    assert_select '.performance-return-trend svg', count: 1
    assert_select '.performance-trend-values tbody tr', count: 3
    assert_operator @response.body.index('performance-return-ratios'), :<, @response.body.index('performance-return-trend')
    assert_operator @response.body.index('Developer comparison'), :<, @response.body.index('Combined results')
    TicketJourneyPerformance.expects(:history_for).with([issue.id], Date.current, include_return_reason: true).returns({})
    TicketJourneyPerformanceReturns.expects(:accumulate_trend!).never
    get :index, params: { project_id: @project.identifier, tab: 'returns', owner_id: '1', metric: 'repeats_2' }
    assert_response :success
    assert_select '.performance-return-ticket', count: 1
    assert_select '.performance-return-trend', count: 0
    assert_select 'li', text: /Consecutive repeat/, count: 2
    assert_select 'a[href=?]', performance_dashboard_path(@project, owner_id: '1', as_of: Date.current.iso8601, tab: 'returns'), text: /Back to Performance Returns/
  end

  test 'Returns has separate metric whitelist and uses existing dashboard authorization' do
    Issue.expects(:visible).never
    get :index, params: { project_id: @project.identifier, tab: 'returns', metric: 'done' }
    assert_response :not_found
    @request.session[:user_id] = 2
    Role.all.each do |role|
      role.permissions = role.permissions - [:view_performance_dashboard]
      role.save!
    end
    get :index, params: { project_id: @project.identifier, tab: 'returns' }
    assert_response :forbidden
  end

  test 'unknown performance tab is rejected before report scans' do
    Issue.expects(:visible).never
    get :index, params: { project_id: @project.identifier, tab: 'unknown' }
    assert_response :not_found
  end

  test 'periodic navigation is above the title and retains context without running reports' do
    Issue.expects(:visible).never
    TicketJourneyPerformance.expects(:calculate).never
    get :index, params: { project_id: @project.identifier, dashboard_type: 'periodic', tab: 'time',
                          owner_ids: ['1', '2'], as_of: Date.current.iso8601 }
    assert_response :success
    assert_select '.performance-header > .performance-navigation', count: 1
    assert_select '.performance-type-tabs a[aria-current="page"]', text: /Periodic Report/
    assert_select '.performance-header h2', text: 'Time — Periodic Report'
    assert_select 'input[name="dashboard_type"][value="periodic"]'
    assert_select '.performance-planned-section', text: /From \/ To date range/
    assert_operator @response.body.index('aria-label="Dashboard type"'), :<, @response.body.index('aria-label="Report section"')
    assert_operator @response.body.index('aria-label="Report section"'), :<, @response.body.index('<h2>')
    assert_select '.performance-tabs a', count: 3 do |links|
      links.each do |link|
        context = Rack::Utils.parse_nested_query(URI.parse(link['href']).query)
        assert_equal 'periodic', context['dashboard_type']
        assert_equal ['1', '2'], context['owner_ids']
        assert_equal Date.current.iso8601, context['as_of']
      end
    end
    assert_select '.performance-type-tabs a', count: 2 do |links|
      live = Rack::Utils.parse_nested_query(URI.parse(links.first['href']).query)
      assert_nil live['dashboard_type']
      assert_equal 'time', live['tab']
      assert_equal ['1', '2'], live['owner_ids']
    end
  end

  test 'unknown dashboard category is rejected before report scans' do
    Issue.expects(:visible).never
    get :index, params: { project_id: @project.identifier, dashboard_type: 'unknown' }
    assert_response :not_found
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
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57), value: '1')])
    TicketJourneyPerformance.stubs(:snapshot).returns({ id: issue.id, owner_id: user.id.to_s, status_name: 'In Progress',
      due: Date.current - 30, open: true, done: false, started: true,
      delivered_at: nil, weight: 5.0, missing_weight: false })
    [nil, 'open'].each do |metric|
      get :index, params: { project_id: @project.identifier, owner_id: user.id, metric: metric, as_of: (Date.current - 30).iso8601 }
      assert_response :success
      assert_select '#owner_id option[value=?]', user.id.to_s, count: 0
      if metric
        assert_select 'tbody tr.performance-ticket-row', count: 1
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
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57), value: '1')])
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
    assert_select '.performance-unavailable', text: /Average: 0/, count: 2
    assert_select '.performance-monthly p', text: /Last 3 completed months:/, count: 2
    Setting.plugin_redmine_ticket_journey = { 'performance_delivery_target' => '92.5' }
    get :index, params: { project_id: @project.identifier, owner_id: '1' }
    assert_response :success
    assert_select '.performance-ratios .performance-metric p', text: /Target: 92.5%/, count: 2
  end

  test 'new and on hold are absent from dashboard open totals and matching drill downs' do
    issues = [Issue.find(1), Issue.find(2), Issue.find(3)]
    issues.each { |issue| issue.update_columns(project_id: @project.id, tracker_id: issues.first.tracker_id) }
    issues.first.tracker.update!(name: 'Bug')
    Issue.expects(:visible).at_least_once.returns(Issue.where(id: issues.map(&:id)))
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57), value: '1')])
    issues.each_with_index do |issue, index|
      TicketJourneyPerformance.stubs(:snapshot).with { |candidate, *rest| candidate.id == issue.id }.returns({
        id: issue.id, owner_id: '1', status_name: %w[New On-Hold Pending][index], due: Date.current,
        open: true, done: false, started: false, delivered_at: nil,
        weight: [100.0, 200.0, 8.0][index], missing_weight: false
      })
    end
    get :index, params: { project_id: @project.identifier, owner_id: '1' }
    assert_response :success
    assert_select '.performance-card-0 .performance-value', text: '1'
    assert_select '.performance-card-0 .performance-weight', text: '8'
    assert_select '.performance-card-0 .performance-secondary', text: /Stopped: 1/
    %w[open stopped due_soon].each do |metric|
      get :index, params: { project_id: @project.identifier, owner_id: '1', metric: metric }
      assert_response :success
      assert_select 'tr.performance-ticket-row', count: 1
      assert_select 'tr.performance-ticket-row a[href=?]', issue_path(issues.last), text: "##{issues.last.id}"
    end
    get :index, params: { project_id: @project.identifier, owner_id: '1', metric: 'due' }
    assert_response :success
    assert_select 'tr.performance-ticket-row', count: 3
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
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57), value: '1')])
    TicketJourneyPerformance.stubs(:snapshot).returns({ id: issue.id, owner_id: '1', status_name: 'Historical Review',
      due: date - 1, open: true, done: false, started: true,
      delivered_at: nil, weight: 5.0, missing_weight: false })
    get :index, params: { project_id: @project.identifier, owner_id: '1', as_of: date.iso8601, metric: 'started' }
    assert_response :success
    assert_select 'tbody tr.performance-ticket-row', count: 1
    assert_select 'td', text: 'Historical Review'
    assert_select 'tr.group', count: 0
    assert_select '.performance-list-options', count: 1
    assert_select 'thead a[href*="sort=due"]', count: 1
    assert_select 'a[href=?]', issue_path(issue), text: "##{issue.id}"
    assert_select 'a[href=?]', performance_dashboard_path(@project, owner_id: 1, as_of: date.iso8601), text: /Back to Performance/
    get :index, params: { project_id: @project.identifier, owner_id: '1', as_of: date.iso8601,
                          metric: 'started', group_by: 'project', detail_options: '1',
                          detail_columns: ['status', 'not_a_column'] }
    assert_response :success
    assert_select 'tr.group th[colspan="2"]', text: /1 tickets/
    assert_select 'table.list thead th', count: 2
    assert_select 'table.list thead th', text: /Status \(as of date\)/
    assert_select 'thead a[href*="sort=status"]' do |links|
      context = Rack::Utils.parse_nested_query(URI.parse(links.first['href']).query)
      assert_equal 'project', context['group_by']
      assert_equal ['id', 'status'], context['detail_columns']
      assert_nil context['page']
    end
    issue.update_column(:estimated_hours, 12.5)
    TimeEntry.expects(:visible).with { |user| user.id == 1 }.returns(TimeEntry.none)
    get :index, params: { project_id: @project.identifier, owner_id: '1', as_of: date.iso8601,
                          metric: 'started', detail_options: '1',
                          detail_columns: %w[priority subject estimate spent status] }
    assert_response :success
    assert_select 'table.list thead th', count: 6
    assert_select 'table.list thead th', text: 'Title / Subject (current)'
    assert_select 'table.list tbody td', text: issue.priority.name
    assert_select 'table.list tbody td', text: '12.50 h'
    assert_select 'table.list tbody td', text: '0.00 h'
    assert_select 'table.list tbody td', text: 'Historical Review'
  end

  test 'drill down cannot disclose an owner without visible matching issues' do
    @controller.stubs(:discover_owner_ids).returns(Set.new)
    User.find(2).update_column(:status, Principal::STATUS_LOCKED)
    Issue.expects(:visible).returns(Issue.none)
    get :index, params: { project_id: @project.identifier, owner_id: '2', metric: 'open' }
    assert_response :not_found
  end

  test 'monthly contributor drill down displays the fixed completed-month range' do
    date = Date.current
    issue = Issue.find(1)
    issue.tracker.update!(name: 'Bug')
    Issue.expects(:visible).at_least_once.returns(Issue.where(id: issue.id))
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57), value: '1')])
    TicketJourneyPerformance.stubs(:snapshot).returns({ id: issue.id, owner_id: '1',
      status_name: 'Done / Closed', due: date, open: false, done: true, started: true,
      delivered_at: date.beginning_of_month - 1, weight: 9.0, missing_weight: false })
    get :index, params: { project_id: @project.identifier, owner_id: '1', as_of: date.iso8601, metric: 'delivered_weight' }
    assert_response :success
    assert_select 'tbody tr.performance-ticket-row', count: 1
    assert_select 'p', text: /Monthly contributors from #{Regexp.escape(@controller.view_context.format_date(date.beginning_of_month << 3))} through #{Regexp.escape(@controller.view_context.format_date(date.beginning_of_month - 1))}/
    assert_select 'p', text: /divides these totals by 3, including zero-delivery months/
  end

  test 'multi owner table precedes aggregated charts and combined drill down preserves owners' do
    User.find(2).update_column(:status, Principal::STATUS_ACTIVE)
    issues = [Issue.find(1), Issue.find(2)]
    issues.each { |issue| issue.update_columns(project_id: @project.id, tracker_id: issues.first.tracker_id) }
    issues.first.tracker.update!(name: 'Bug')
    Issue.expects(:visible).at_least_once.returns(Issue.where(id: issues.map(&:id)))
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57), value: '1')])
    issues.each_with_index do |issue, index|
      TicketJourneyPerformance.stubs(:snapshot).with { |candidate, *rest| candidate.id == issue.id }.returns({
        id: issue.id, owner_id: (index + 1).to_s, status_name: 'In Progress',
        due: Date.current + (index.zero? ? -1 : 1), open: true, done: false, started: true,
        delivered_at: nil, weight: (index + 1) * 5.0, missing_weight: false
      })
    end
    get :index, params: { project_id: @project.identifier, owner_ids: ['1', '2', '1'] }
    assert_response :success
    assert_select 'details.performance-comparison[open]', count: 1
    assert_select '.performance-comparison tbody tr', count: 2
    assert_select '.performance-comparison tfoot td:first-of-type', text: '2'
    assert_select '.performance-card-0 .performance-value', text: '2'
    assert_operator @response.body.index('performance-comparison'), :<, @response.body.index('Combined results for selected owners')
    get :index, params: { project_id: @project.identifier, owner_ids: ['1', '2'], metric: 'open', sort: 'weight', direction: 'desc' }
    assert_response :success
    assert_select 'tr.performance-ticket-row', count: 2
    assert_select 'a', text: 'Open matching tickets in Issues (current values)' do |links|
      native_params = Rack::Utils.parse_nested_query(URI.parse(links.first['href']).query)
      assert_equal issues.map(&:id).sort, native_params.dig('v', 'issue_id').first.split(',').map(&:to_i).sort
      assert_equal '*', native_params.dig('op', 'status_id')
      assert_equal '', native_params['group_by']
    end
    assert_select 'a[href=?]', performance_dashboard_path(@project, owner_ids: ['1', '2'], as_of: Date.current.iso8601), text: /Back to Performance/
  end

  test 'monthly targets reject private fields for non administrators' do
    user = User.find(2)
    User.stubs(:current).returns(user)
    field = stub(field_format: 'int', visible?: false)
    UserCustomField.expects(:find_by).with(id: 100).returns(field)
    assert_nil @controller.send(:monthly_target, '100')
  end

  test 'monthly targets read each owner value while reusing field metadata' do
    field = stub(id: 100, field_format: 'float', visible?: true)
    UserCustomField.expects(:find_by).with(id: 100).once.returns(field)
    first = stub('first owner')
    second = stub('second owner')
    first.expects(:custom_value_for).with(100).returns(stub(value: '10'))
    second.expects(:custom_value_for).with(100).returns(stub(value: '20'))
    assert_equal 10.0, @controller.send(:monthly_target, '100', first)
    assert_equal 20.0, @controller.send(:monthly_target, '100', second)
  end

  test 'combined monthly view compares per owner actuals with mean targets and retains contributors' do
    User.find(2).update_column(:status, Principal::STATUS_ACTIVE)
    owners = [User.find(1), User.find(2)]
    issues = [Issue.find(1), Issue.find(2)]
    issues.each { |issue| issue.update_columns(project_id: @project.id, tracker_id: issues.first.tracker_id) }
    issues.first.tracker.update!(name: 'Bug')
    Issue.expects(:visible).at_least_once.returns(Issue.where(id: issues.map(&:id)))
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57), value: '1')])
    issues.each_with_index do |issue, index|
      TicketJourneyPerformance.stubs(:snapshot).with { |candidate, *rest| candidate.id == issue.id }.returns({
        id: issue.id, owner_id: '1', status_name: 'Done / Closed', due: Date.current,
        open: false, done: true, started: true, delivered_at: Date.current.beginning_of_month - 1,
        weight: (index + 1) * 6.0, missing_weight: false
      })
    end
    # Owner 2 has zero deliveries and must still count in actual/target means.
    Setting.plugin_redmine_ticket_journey = { 'performance_count_field_id' => '100', 'performance_weight_field_id' => '101' }
    owners.each_with_index do |owner, index|
      @controller.stubs(:monthly_target).with('100', owner).returns((index + 1) * 10.0)
      @controller.stubs(:monthly_target).with('101', owner).returns((index + 1) * 8.0)
    end
    get :index, params: { project_id: @project.identifier, owner_ids: ['1', '2', '1'] }
    assert_response :success
    report = @controller.instance_variable_get(:@report)
    assert_in_delta 1.0 / 3, report[:monthly_count], 0.0001
    assert_equal 3.0, report[:monthly_weight]
    assert_equal [15.0, 12.0], @controller.instance_variable_get(:@targets)
    assert_equal 2, report[:detail_sets]['delivered'].size
    assert_select '.performance-monthly', text: /Per owner · 2 selected owners/, count: 2
    @controller.stubs(:monthly_target).with('101', owners.last).returns(nil)
    get :index, params: { project_id: @project.identifier, owner_ids: ['1', '2'] }
    assert_response :success
    assert_equal [15.0, nil], @controller.instance_variable_get(:@targets)
    assert_select '.performance-monthly', text: /1 selected owner\(s\).*#{Regexp.escape(owners.last.name)}/, count: 1
    get :index, params: { project_id: @project.identifier, owner_ids: ['1', '2'], metric: 'delivered_weight' }
    assert_response :success
    assert_select 'tr.performance-ticket-row', count: 2
    assert_select 'p', text: /then by 2 selected owner\(s\) for per-owner actuals/
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
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: 57), value: '1')])
    TicketJourneyPerformance.stubs(:snapshot).returns({ id: issue.id, owner_id: '1', status_name: 'In Progress',
      due: Date.current, open: true, done: false, started: true,
      delivered_at: nil, weight: 5.0, missing_weight: false })
    get :index, params: { project_id: @project.identifier, owner_id: '1', metric: 'open' }
    assert_response :success
    assert_select 'tbody tr.performance-ticket-row', count: 1
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
