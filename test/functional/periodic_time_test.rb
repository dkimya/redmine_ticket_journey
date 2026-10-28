require File.expand_path('../test_helper', __dir__)

class PeriodicTimeTest < ActionController::TestCase
  tests PerformanceDashboardController
  fixtures :all

  setup do
    @request.session[:user_id] = 1
    @project = Project.find(1)
    @project.enabled_module_names |= ['ticket_journey']
    @first, @last = Date.new(2020, 1, 1), Date.new(2020, 1, 31)
    Setting.plugin_redmine_ticket_journey = { 'performance_periodic_dtc_target' => '10',
      'performance_periodic_priority_dtc_target' => '7', 'performance_periodic_owner_share' => '90' }
  end

  test 'initial Periodic Time is provisional and does not query issues entries or targets' do
    Issue.expects(:visible).never
    TimeEntry.expects(:visible).never
    TicketJourneyPeriodicTime.expects(:load_hours).never
    get :index, params: context
    assert_response :success
    assert_select '.performance-planned-section', count: 0
    assert_select '.periodic-time-kpi', count: 0
    assert_select '.performance-tabs a[aria-current="page"]', text: /Time.*Provisional/
    assert_select '.nodata', text: /does not scan/
  end

  test 'eight metrics use independent personal and ticket cost populations with reconciliation' do
    prepare_scan
    get :index, params: context.merge(owner_id: '1')
    assert_response :success
    report = @controller.instance_variable_get(:@periodic_time_report)
    assert_equal 10.0, report[:metrics]['ticket_cost'][:actual]
    assert_equal 7.0, report[:metrics]['total_hours'][:actual]
    assert_equal 4.0, report[:metrics]['expected_done_hours'][:actual]
    assert_equal 3.0, report[:metrics]['other_hours'][:actual]
    assert_equal 3.0, report[:metrics]['other_hours'][:extra_hours]
    assert_equal 7.0, report[:breakdown].values.sum
    assert_select '.periodic-time-kpi', count: 8
    assert_select '.periodic-time-trend', minimum: 5
    assert_select '.periodic-summary details[open]', count: 0
    assert_select '.periodic-time-breakdown', count: 1
    assert_select '.periodic-time-mix-donut', count: 6
    assert_equal 7.0, @controller.instance_variable_get(:@time_mix)[:personal_summary][:total]
    assert_equal 6.0, @controller.instance_variable_get(:@time_mix)[:package_summary][:total]
    assert_select '.periodic-time-kpi a[target="_blank"]', minimum: 8
  end

  test 'multi-owner totals do not rewrite entry users and keep Mixed Extra Work' do
    prepare_scan
    User.find(2).update_column(:status, Principal::STATUS_ACTIVE)
    get :index, params: context.merge(owner_ids: ['1', '2'])
    assert_response :success
    report = @controller.instance_variable_get(:@periodic_time_report)
    assert_equal 15.0, report[:metrics]['ticket_cost'][:actual]
    assert_equal 9.0, report[:metrics]['total_hours'][:actual]
    assert_equal 3.0, report[:metrics]['other_hours'][:extra_hours]
    assert_equal 2.0, report[:metrics]['other_hours'][:unplanned_hours]
    assert_select 'p', text: /Mixed Extra \/ Unplanned Work/, minimum: 1
    entries = @controller.instance_variable_get(:@periodic_time_owners)
    assert_equal 2.0, entries.find { |entry| entry[:owner].id == 2 }[:report][:metrics]['total_hours'][:actual]
    assert_select '.periodic-time-owner-trends', count: 1
    assert_select '.periodic-time-owner-trends[open]', count: 0
    assert_select '.periodic-time-trend a[target="_blank"]', minimum: 1 do |links|
      individual = links.find { |link| Rack::Utils.parse_nested_query(URI.parse(link['href']).query)['owner_id'] == '2' }
      assert individual
      query = Rack::Utils.parse_nested_query(URI.parse(individual['href']).query)
      assert_nil query['owner_ids']
      assert_equal 'time', query['tab']
      assert_equal 'periodic', query['dashboard_type']
      assert query['time_bucket']
    end
  end

  test 'work-date contributor list retains bucket range logged-user and current-owner distinction' do
    issues = prepare_scan
    bucket = TicketJourneyPeriodicReturns.intervals(@first, @last).find { |first, last| (@first + 2).between?(first, last) }.last
    get :index, params: context.merge(owner_id: '1', metric: 'total_hours', time_bucket: bucket.iso8601, time_group: 'project')
    assert_response :success
    assert_select '.periodic-time-ticket', count: 2
    assert_equal issues.map(&:id).sort, @controller.instance_variable_get(:@matching_issue_ids).sort
    assert_select 'th', text: 'Report Owner / Logged User'
    assert_select 'th', text: 'Current Ticket Owner'
    assert_select 'form input[name="time_bucket"][value=?]', bucket.iso8601
    assert_select 'form input[name="rsd"][value=?]', @first.iso8601
    assert_select 'select[name="time_group"] option[selected][value="project"]'
    assert_select '.group', text: /all pages/
    assert_select 'a[data-performance-back]' do |links|
      query = Rack::Utils.parse_nested_query(URI.parse(links.first['href']).query)
      assert_equal 'time', query['tab']
      assert_equal 'periodic', query['dashboard_type']
      assert_nil query['metric']
      assert_nil query['time_bucket']
    end
  end

  test 'hidden Ticket Owner preserves logged-user hours as unclassified without ownership leakage' do
    issues = prepare_scan(hidden_second: true)
    get :index, params: context.merge(owner_id: '1', metric: 'unclassified')
    assert_response :success
    assert_select '.periodic-time-ticket', count: 1
    assert_equal [issues.last.id], @controller.instance_variable_get(:@matching_issue_ids)
    assert_select '.periodic-time-ticket td', text: 'Unavailable', minimum: 1
    assert_empty @controller.instance_variable_get(:@current_owner_names)
  end

  test 'incomplete project time permission does not present total hours as zero' do
    prepare_scan
    @controller.stubs(:periodic_time_project_permissions).returns({ @project.id => false })
    get :index, params: context.merge(owner_id: '1')
    assert_response :success
    report = @controller.instance_variable_get(:@periodic_time_report)
    assert_nil report[:metrics]['total_hours'][:actual]
    assert_nil report[:valid_visible_hours]
    assert_nil report[:metrics]['ticket_cost'][:actual]
    assert_select '.periodic-provisional', text: /Time-view permission is incomplete/
  end

  test 'invalid bucket or another section metric is rejected before time scans' do
    Issue.expects(:visible).never
    TimeEntry.expects(:visible).never
    [context.merge(owner_id: '1', metric: 'returns_open'),
      context.merge(owner_id: '1', metric: 'time_mix', mix_scope: 'invalid'),
      context.merge(owner_id: '1', metric: 'total_hours', time_bucket: (@last + 1).iso8601)].each do |params|
      get :index, params: params
      assert_response :not_found
    end
  end

  test 'activity audit uses all package contributors and retains filters grouping and native IDs' do
    issues = prepare_scan
    activity = TimeEntryActivity.first
    get :index, params: context.merge(owner_id: '1', metric: 'time_mix', mix_scope: 'package', mix_user: '2',
      mix_activity: activity.id.to_s, mix_tracker: 'Bug', mix_group: 'user')
    assert_response :success
    assert_select '.periodic-time-mix-row', count: 1
    assert_equal [issues.first.id], @controller.instance_variable_get(:@matching_issue_ids)
    assert_equal 2.0, @controller.instance_variable_get(:@mix_summary)[:total]
    assert_select 'form input[name="mix_user"][value="2"]'
    assert_select 'form input[name="mix_tracker"][value="Bug"]'
    assert_select '.group', text: /all pages/
    get :index, params: context.merge(owner_id: '1', metric: 'time_mix', mix_scope: 'personal', mix_user: '2')
    assert_response :success
    assert_select '.periodic-time-mix-row', count: 0
  end

  test 'archived effort stays paid without output and activity mapping remains explicit' do
    issues = prepare_scan(archived_second: true)
    get :index, params: context.merge(owner_id: '1')
    assert_response :success
    report = @controller.instance_variable_get(:@periodic_time_report)
    assert_equal 7.0, report[:metrics]['total_hours'][:actual]
    assert_equal 3.0, report[:breakdown]['archived']
    assert_equal 0.0, report[:metrics]['other_hours'][:actual]
    assert_nil @controller.instance_variable_get(:@time_mix)[:package_summary][:development_share]
    assert_select '.periodic-time-mix p', text: /Development activities have not been mapped/
    get :index, params: context.merge(owner_id: '1', metric: 'archived_hours')
    assert_response :success
    assert_equal [issues.last.id], @controller.instance_variable_get(:@matching_issue_ids)
  end

  private

  def context
    { project_id: @project.identifier, dashboard_type: 'periodic', tab: 'time', rsd: @first.iso8601, red: @last.iso8601 }
  end

  def prepare_scan(hidden_second: false, archived_second: false)
    issues = [Issue.find(1), Issue.find(2)]
    issues.first.tracker.update!(name: 'Bug')
    issues.each { |issue| issue.update_columns(project_id: @project.id, tracker_id: issues.first.tracker_id, created_on: (@first - 5).in_time_zone) }
    Issue.stubs(:visible).returns(Issue.where(id: issues.map(&:id)))
    TicketJourneyPerformance.stubs(:batch_field_values).returns(issues.each_with_index.to_h do |issue, index|
      [issue.id, hidden_second && index == 1 ? [] : [TicketJourneyPerformance::FieldValue.new(stub(id: 57), (index + 1).to_s)]]
    end)
    TicketJourneyPeriodicTickets.stubs(:history_for).returns({})
    @controller.stubs(:periodic_time_project_permissions).returns({ @project.id => true })
    logs = { issues.first.id => { '1' => [[@first + 1, 4.0]], '2' => [[@first + 1, 2.0]] },
      issues.last.id => { '1' => [[@first + 2, 3.0]] } }
    activity = TimeEntryActivity.first
    mix = logs.to_h do |id, users|
      [id, users.flat_map { |user, entries| entries.map { |day, hours| { user_id: user, activity_id: activity.id.to_s, day: day, hours: hours } } }]
    end
    TicketJourneyPeriodicTime.stubs(:load_hours).returns({ costs: { issues.first.id => 10.0, issues.last.id => 5.0 },
      logs: logs, invalid_costs: {}, invalid_logs: {}, mix: mix })
    issues.each_with_index do |issue, index|
      issue.update_column(:estimated_hours, 10)
      TicketJourneyPeriodicTickets.stubs(:row).with { |candidate, *rest| candidate.id == issue.id }.returns(
        { id: issue.id, owner_id: (index + 1).to_s, due: index.zero? ? @first + 5 : nil,
          beginning_open: false, closed_before: false, hotfix: false, assigned_on: @first,
          done: true, delivered_at: @first + 3, status_name: 'Done / Closed', current_open: false,
          current_status_name: archived_second && index == 1 ? 'Archived' : 'Done / Closed',
          weight: 5.0, missing_weight: false, project_id: @project.id, project_name: @project.name,
          tracker_name: 'Bug', subject: issue.subject })
    end
    issues
  end
end
