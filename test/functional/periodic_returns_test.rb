require File.expand_path('../test_helper', __dir__)

class PeriodicReturnsTest < ActionController::TestCase
  tests PerformanceDashboardController
  fixtures :all

  setup do
    @request.session[:user_id] = 1
    @project = Project.find(1)
    @project.enabled_module_names |= ['ticket_journey']
    @first, @last = Date.new(2020, 1, 1), Date.new(2020, 1, 31)
  end

  test 'initial Returns shows provisional filters without issue or return history scans' do
    Issue.expects(:visible).never
    TicketJourneyPeriodicTickets.expects(:history_for).never
    TicketJourneyPerformanceReturns.expects(:events_for).never
    get :index, params: context
    assert_response :success
    assert_select '.nodata', text: /click Apply/
    assert_select '.periodic-provisional', text: /full recorded history through RED/i
    assert_select '.periodic-return-kpis', count: 0
    assert_select '.performance-tabs a[aria-current="page"]', text: /Returns.*Provisional/
  end

  test 'completed populations match Tickets and expected versus total metrics remain separate' do
    prepare_scan
    get :index, params: context.merge(owner_id: '1')
    assert_response :success
    report = @controller.instance_variable_get(:@periodic_return_report)
    tickets = @controller.instance_variable_get(:@periodic_report)
    assert_equal tickets[:sets]['completed'].map { |row| row[:id] }, report[:sets]['returns_open'].map { |row| row[:id] }
    assert_equal tickets[:sets]['actual'].map { |row| row[:id] }, report[:sets]['total_open'].map { |row| row[:id] }
    assert_equal 2.0, report[:expected][:ratio]
    assert_equal 3.0, report[:total][:ratio]
    assert_select '.periodic-summary details[open]', count: 0
    assert_select '.periodic-return-kpis', count: 2
    assert_select '.performance-return-distributions .performance-donut', count: 2
    assert_select '.periodic-return-trend', count: 1
    assert_select '.performance-leaderboard-threshold', count: 0
    assert_select '.performance-return-distributions table tfoot', count: 2
  end

  test 'multi-owner table and cohort links do not retain a competing team owner parameter' do
    prepare_scan
    user = User.find(2)
    user.update_column(:status, Principal::STATUS_ACTIVE)
    Member.create!(project: @project, principal: user, roles: [Role.find(1)]) unless Member.exists?(project_id: @project.id, user_id: 2)
    get :index, params: context.merge(owner_ids: ['1', '2'])
    assert_response :success
    entries = @controller.instance_variable_get(:@periodic_return_owners)
    assert_equal 0, entries.find { |entry| entry[:owner].id == 2 }[:report][:expected][:population]
    assert_select '.periodic-return-comparison:first-of-type tbody tr', minimum: 3 do |rows|
      rows.first(2).each_with_index do |row, index|
        row.css('a').each do |link|
          query = Rack::Utils.parse_nested_query(URI.parse(link['href']).query)
          assert_equal entries[index][:owner].id.to_s, query['owner_id']
          assert_nil query['owner_ids']
          assert_equal 'returns', query['tab']
          assert_equal 'periodic', query['dashboard_type']
          assert_equal @first.iso8601, query['rsd']
          assert_equal @last.iso8601, query['red']
          assert_equal '_blank', link['target']
        end
      end
    end
    assert_select '[data-leaderboard-toggle]', count: 2
  end

  test 'cohort audit preserves context grouping event reasons and all contributor IDs' do
    issues = prepare_scan
    bucket = TicketJourneyPeriodicReturns.intervals(@first, @last).find { |first, last| (@first + 3).between?(first, last) }.last
    get :index, params: context.merge(owner_id: '1', metric: 'trend_returned', trend_date: bucket.iso8601, group_by: 'project')
    assert_response :success
    assert_select '.performance-return-ticket', count: 1
    assert_equal [issues.first.id], @controller.instance_variable_get(:@matching_issue_ids)
    assert_select 'form input[name="dashboard_type"][value="periodic"]'
    assert_select 'form input[name="rsd"][value=?]', @first.iso8601
    assert_select 'form input[name="trend_date"][value=?]', bucket.iso8601
    assert_select 'th', text: 'Completion Date'
    assert_select 'li', text: /Merge Conflict/, minimum: 1
    assert_select 'a[data-performance-back]' do |links|
      query = Rack::Utils.parse_nested_query(URI.parse(links.first['href']).query)
      assert_equal 'periodic', query['dashboard_type']
      assert_equal 'returns', query['tab']
      assert_nil query['metric']
      assert_nil query['trend_date']
    end
  end

  test 'hidden owner never loads its return history or leaks contributions' do
    issue = Issue.find(1)
    issue.tracker.update!(name: 'Bug')
    Issue.stubs(:visible).returns(Issue.where(id: issue.id))
    TicketJourneyPerformance.stubs(:batch_field_values).returns({ issue.id => [] })
    TicketJourneyPeriodicTickets.expects(:history_for).never
    TicketJourneyPeriodicReturns.expects(:enrich).never
    Member.create!(project: @project, principal: User.find(1), roles: [Role.find(1)]) unless Member.exists?(project_id: @project.id, user_id: 1)
    get :index, params: context.merge(owner_id: '1')
    assert_response :success
    assert_equal 0, @controller.instance_variable_get(:@returns)[:population]
  end

  test 'invalid cohort dates and cross-section metrics are rejected before scans' do
    Issue.expects(:visible).never
    [context.merge(owner_id: '1', metric: 'expected'),
      context.merge(owner_id: '1', metric: 'trend_returned', trend_date: (@first - 1).iso8601),
      context.merge(owner_id: '1', metric: 'trend_expected', trend_date: (@last + 1).iso8601)].each do |params|
      get :index, params: params
      assert_response :not_found
    end
  end

  private

  def context
    { project_id: @project.identifier, dashboard_type: 'periodic', tab: 'returns', rsd: @first.iso8601, red: @last.iso8601 }
  end

  def prepare_scan
    issues = [Issue.find(1), Issue.find(2)]
    issues.first.tracker.update!(name: 'Bug')
    issues.each { |issue| issue.update_columns(project_id: @project.id, tracker_id: issues.first.tracker_id) }
    Issue.stubs(:visible).returns(Issue.where(id: issues.map(&:id)))
    TicketJourneyPerformance.stubs(:batch_field_values).returns(issues.to_h do |issue|
      [issue.id, [TicketJourneyPerformance::FieldValue.new(stub(id: 57), '1')]]
    end)
    TicketJourneyPeriodicTickets.expects(:history_for).with(issues.map(&:id).sort, @last, include_return_reason: true).returns({})
    issues.each_with_index do |issue, index|
      TicketJourneyPeriodicTickets.stubs(:row).with { |candidate, *rest| candidate.id == issue.id }.returns(
        { id: issue.id, owner_id: '1', due: index.zero? ? @first + 5 : nil,
          beginning_open: false, closed_before: false, hotfix: false, assigned_on: @first,
          done: true, delivered_at: @first + 3, status_name: 'Done / Closed', current_open: false,
          weight: 5.0, missing_weight: false, project_id: @project.id, project_name: @project.name,
          tracker_name: 'Bug', subject: issue.subject })
      events = Array.new(index.zero? ? 2 : 4) do |number|
        { journal_id: number + 1, at: (@first - 2).in_time_zone, from_status: 'Feedback',
          reason: number.zero? ? 'Merge / Integration Conflict' : nil,
          repeat: number.positive?, merge_conflict: number.zero? ? true : nil }
      end
      TicketJourneyPerformanceReturns.stubs(:events_for).with { |candidate, *rest| candidate.id == issue.id }.returns(events)
    end
    issues
  end
end
