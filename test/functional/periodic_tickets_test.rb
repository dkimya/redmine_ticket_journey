require File.expand_path('../test_helper', __dir__)

class PeriodicTicketsTest < ActionController::TestCase
  tests PerformanceDashboardController
  fixtures :all

  setup do
    @request.session[:user_id] = 1
    @project = Project.find(1)
    @project.enabled_module_names |= ['ticket_journey']
    @first, @last = Date.new(2020, 1, 1), Date.new(2020, 1, 31)
  end

  test 'initial Tickets loads confirmed rules without scans or metrics' do
    Issue.expects(:visible).never
    TicketJourneyPeriodicTickets.expects(:history_for).never
    get :index, params: context
    assert_response :success
    assert_select '.nodata', text: /click Apply/
    assert_select '.periodic-provisional', text: /rules have been confirmed/
    assert_select '.periodic-flow', count: 0
    assert_select 'input[name="rsd"][value=?]', @first.iso8601
    assert_select '.performance-tabs a[aria-current="page"]', text: 'Tickets'
  end

  test 'dashboard renders all visual blocks and owner-specific links without team parameter leakage' do
    prepare_scan
    user = User.find(2)
    user.update_column(:status, Principal::STATUS_ACTIVE)
    Member.create!(project: @project, principal: user, roles: [Role.find(1)]) unless Member.exists?(project_id: @project.id, user_id: user.id)
    get :index, params: context.merge(owner_ids: ['1', '2'])
    assert_response :success
    assert_select '.periodic-kpi', count: 7
    assert_select '.periodic-trend', count: 4
    assert_select '.periodic-trend[data-performance-leaderboard]', count: 2 do |charts|
      charts.each do |chart|
        assert_equal 2, chart.css('[data-leaderboard-toggle][aria-pressed="true"]').size
        assert_equal 4, chart.css('g[data-leaderboard-series]').size
        chart.css('[data-leaderboard-toggle]').each do |button|
          owner_id = button['data-leaderboard-toggle']
          assert_equal 2, chart.css("g[data-leaderboard-series='#{owner_id}']").size
          assert_equal 'lines', button['data-line-description']
        end
        assert_empty chart.css('.performance-trend-legend')
        assert_equal 1, chart.css('.performance-leaderboard-layout .performance-leaderboard-legend').size
        assert_equal 1, chart.css('.performance-trend-values table').size
      end
    end
    assert_select 'script[src*="performance_leaderboard"]', count: 1
    assert_select '.periodic-summary', count: 1
    assert_select '.periodic-summary details[open]', count: 0
    assert_select '.periodic-owner-table tbody tr', count: 2
    assert_select '.periodic-summary a[target="_blank"]', minimum: 1
    entries = @controller.instance_variable_get(:@periodic_owners)
    assert_select '.periodic-owner-table tbody tr', count: 2 do |rows|
      rows.each_with_index do |row, index|
        row.css('a').each do |link|
          params = Rack::Utils.parse_nested_query(URI.parse(link['href']).query)
          assert_equal entries[index][:owner].id.to_s, params['owner_id']
          assert_nil params['owner_ids']
          assert_equal @first.iso8601, params['rsd']
          assert_equal @last.iso8601, params['red']
        end
      end
    end
    summary = @controller.instance_variable_get(:@periodic_report)[:summaries]
    assert_equal 1, summary['expected'][:count]
    assert_equal 1, summary['completed'][:count]
  end

  test 'drilldown preserves range metric grouping and trend context with exact contributors' do
    issue = prepare_scan
    get :index, params: context.merge(owner_id: '1', metric: 'trend_completed', trend_date: @last.iso8601, group_by: 'project')
    assert_response :success
    assert_select 'tr.performance-ticket-row', count: 1
    assert_select 'a[href=?]', issue_path(issue), count: 1
    assert_equal [issue.id], @controller.instance_variable_get(:@matching_issue_ids)
    assert_select 'th a', minimum: 1 do |links|
      link = links.find { |item| item.text == 'Ticket' }
      query = Rack::Utils.parse_nested_query(URI.parse(link['href']).query)
      assert_equal 'periodic', query['dashboard_type']
      assert_equal @first.iso8601, query['rsd']
      assert_equal @last.iso8601, query['red']
      assert_equal @last.iso8601, query['trend_date']
      assert_equal 'project', query['group_by']
    end
    assert_select 'a[data-performance-back]' do |links|
      query = Rack::Utils.parse_nested_query(URI.parse(links.first['href']).query)
      assert_equal 'periodic', query['dashboard_type']
      assert_nil query['metric']
    end
  end

  test 'hidden owner fields do not load history or expose contributors' do
    issue = Issue.find(1)
    issue.tracker.update!(name: 'Bug')
    Issue.stubs(:visible).returns(Issue.where(id: issue.id))
    TicketJourneyPerformance.stubs(:batch_field_values).returns({ issue.id => [] })
    TicketJourneyPeriodicTickets.expects(:history_for).never
    Member.create!(project: @project, principal: User.find(1), roles: [Role.find(1)]) unless Member.exists?(project_id: @project.id, user_id: 1)
    get :index, params: context.merge(owner_id: '1')
    assert_response :success
    assert_equal 0, @controller.instance_variable_get(:@periodic_report)[:summaries]['expected'][:count]
  end

  test 'unknown metrics invalid owner IDs and invalid trend buckets are rejected before scans' do
    Issue.expects(:visible).never
    [context.merge(metric: 'owner_changes'), context.merge(owner_id: 'invalid'),
      context.merge(owner_id: '1', metric: 'trend_expected', trend_date: (@last + 1).iso8601)].each do |params|
      get :index, params: params
      assert_response :not_found
    end
  end

  test 'initial Periodic Time retains the period without scans' do
    Issue.expects(:visible).never
    %w[time].each do |tab|
      get :index, params: context.merge(tab: tab)
      assert_response :success
      assert_select '.periodic-time-page', count: 1
      assert_select '.nodata', text: /does not scan/
      assert_select '.periodic-flow', count: 0
    end
  end

  test 'extraordinary audit links to exact tickets and shows responsibility and reasons' do
    issue = prepare_scan(todo_on: @first + 1, current_done: false, current_open: true,
      current_status_name: 'In Progress', extraordinary_reasons: ['Reopened after Done / Closed', 'Due date changed'])
    get :index, params: context.merge(owner_id: '1', metric: 'extraordinary')
    assert_response :success
    assert_equal [issue.id], @controller.instance_variable_get(:@matching_issue_ids)
    assert_select '.performance-ticket-row', count: 1
    assert_select 'th', text: 'Latest To-Do for Current Owner'
    assert_select 'td', text: /Reopened after Done.*Due date changed/
    get :index, params: context.merge(owner_id: '1')
    report = @controller.instance_variable_get(:@periodic_report)
    assert_empty report[:sets]['completed']
    assert_equal [issue.id], report[:sets]['debt'].map { |row| row[:id] }
    assert_select '.periodic-data-quality a', text: /Extraordinary Tickets: 1/
  end

  private

  def context
    { project_id: @project.identifier, dashboard_type: 'periodic', rsd: @first.iso8601, red: @last.iso8601 }
  end

  def prepare_scan(**overrides)
    issue = Issue.find(1)
    issue.tracker.update!(name: 'Bug')
    Issue.stubs(:visible).returns(Issue.where(id: issue.id))
    TicketJourneyPerformance.stubs(:batch_field_values).returns({ issue.id => [
      TicketJourneyPerformance::FieldValue.new(stub(id: 57), '1')
    ] })
    TicketJourneyPeriodicTickets.stubs(:history_for).returns({})
    TicketJourneyPeriodicTickets.stubs(:row).returns({ id: issue.id, owner_id: '1', due: @first + 5,
      beginning_open: false, closed_before: false, hotfix: false, assigned_on: @first,
      done: true, delivered_at: @first + 3, status_name: 'Done / Closed', current_open: false,
      weight: 8.0, missing_weight: false, project_id: issue.project_id, project_name: issue.project.name,
      tracker_name: 'Bug', subject: issue.subject }.merge(overrides))
    issue
  end
end
