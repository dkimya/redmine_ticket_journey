class TicketJourneyController < ApplicationController
  TICKET_OWNER_CF_ID = 57
  TICKET_ORIGINAL_SPRINT_CF_ID = 68
  BUG_SOURCE_CF_ID = 63
  BUG_IMPACT_RATING_CF_ID = 65
  RETURN_REASON_CF_ID = 66
  OWNER_RETURN_SORTABLE_FIELDS = %w[owner total_tickets ticket_share done_tickets avg_done_cycle_time avg_priority_done_cycle_time returned_tickets return_rate c1 c2 c3 c4 total_returns].freeze
  OWNER_WORKLOAD_SORTABLE_FIELDS = %w[owner total_open technical_open task_open stopped overdue priority_open no_due_date avg_age oldest_age].freeze
  AGING_RISK_SORTABLE_FIELDS = %w[group total_open bucket_0_7 bucket_8_14 bucket_15_30 bucket_31_60 bucket_60_plus stopped overdue priority_open no_due_date avg_age oldest_age].freeze
  PRIORITY_RISK_SORTABLE_FIELDS = %w[issue subject owner priority status tracker due_date age_days overdue stopped no_due_date].freeze
  CYCLE_DISTRIBUTION_SORTABLE_FIELDS = %w[group completed_count avg_cycle_hours max_cycle_hours bucket_0_2 bucket_3_7 bucket_8_14 bucket_15_30 bucket_30_plus].freeze
  CYCLE_DISTRIBUTION_GROUP_OPTIONS = {
    'family' => 'Tracker Family',
    'owner' => 'Ticket Owner',
    'tracker' => 'Tracker'
  }.freeze
  CYCLE_DISTRIBUTION_BUCKETS = [
    { key: :bucket_0_2, label: '0-2d', min_hours: 0, max_hours: 48 },
    { key: :bucket_3_7, label: '3-7d', min_hours: 48, max_hours: 168 },
    { key: :bucket_8_14, label: '8-14d', min_hours: 168, max_hours: 336 },
    { key: :bucket_15_30, label: '15-30d', min_hours: 336, max_hours: 720 },
    { key: :bucket_30_plus, label: '30d+', min_hours: 720, max_hours: nil }
  ].freeze
  AGING_RISK_GROUP_OPTIONS = {
    'owner' => 'Ticket Owner',
    'tracker' => 'Tracker',
    'status' => 'Status',
    'priority' => 'Priority'
  }.freeze
  AGING_BUCKETS = [
    { key: :bucket_0_7, label: '0-7d', min: 0, max: 7 },
    { key: :bucket_8_14, label: '8-14d', min: 8, max: 14 },
    { key: :bucket_15_30, label: '15-30d', min: 15, max: 30 },
    { key: :bucket_31_60, label: '31-60d', min: 31, max: 60 },
    { key: :bucket_60_plus, label: '60d+', min: 61, max: nil }
  ].freeze
  BUG_ANALYSIS_SORTABLE_FIELDS = %w[reason beginning beginning_percent found found_percent closed closed_percent remaining remaining_percent impact_sum impact_average change_percent].freeze
  RELEASE_READINESS_SORTABLE_FIELDS = %w[name project due_date status total open done done_percent stopped overdue no_owner no_due_date priority_open risk].freeze
  DATA_QUALITY_SORTABLE_FIELDS = %w[project total_active missing_required missing_required_percent no_update_percent missing_owner_percent missing_estimation_percent reliability_rank].freeze
  DATA_QUALITY_DEFAULT_STALE_DAYS = 7
  PROJECT_HEALTH_ACTIVE_STATUS_ROLES = %i[todo in_progress feedback review ready_merge final_check].freeze
  TRACKER_FAMILY_ORDER = %i[internal customer_support task container].freeze
  TRACKER_FAMILY_DEFINITIONS = {
    internal: {
      label: 'Technical Ticket Journey',
      tracker_names: ['Bug', 'Change Request', 'Change Request / Improvement', 'Feature']
    },
    customer_support: {
      label: 'Customer Support',
      tracker_names: ['Customer Support']
    },
    task: {
      label: 'Task (Business Jobs)',
      tracker_names: ['Task', 'Task (Business Jobs)']
    },
    container: {
      label: 'Container Trackers',
      tracker_names: ['Phase', 'Milestone', 'Milestones', 'Epic', 'Sprint']
    }
  }.freeze
  FAMILY_DURATION_KEYS = {
    internal: %i[D0 D0aug D1 D1aug D2 D2aug D3 D3aug D4 D4aug D5 D5aug D6 D6aug D7 D8 D9],
    customer_support: %i[DC0 DC1 DC2 DC3 DC4 DC5 DC6 DC7],
    task: %i[DT0 DT1 DT1aug DT2 DT2aug DT3 DT3aug DT4 DT4aug],
    container: %i[DP0 DP1 DP2 DP3]
  }.freeze
  FAMILY_COUNTER_KEYS = {
    internal: %i[C1 C2 C3 C4],
    customer_support: [],
    task: %i[C1 C4],
    container: []
  }.freeze
  FLOW_STATUS_ORDER = [
    'New',
    'To-Do',
    'In Progress',
    'Feedback',
    'Review',
    'Ready to Merge',
    'Final Check',
    'Returned',
    'Pending',
    'On-Hold',
    'Done / Closed',
    'Archived'
  ].freeze
  FLOW_STATUS_SEPARATOR_BEFORE = ['To-Do', 'Pending', 'Done / Closed'].freeze
  ALL_DURATION_KEYS = (FAMILY_DURATION_KEYS.values.flatten + [:ON_HOLD, :PENDING, :TOTAL, :CALENDAR_TOTAL]).freeze
  ALL_COUNTER_KEYS = %i[C1 C2 C3 C4].freeze

  before_action :find_project
  before_action :authorize
  before_action :build_query, only: [:index, :pmo_control, :sprint_delivery, :owner_returns, :owner_workload, :aging_risk, :priority_risk, :cycle_distribution, :flow_report, :project_health, :release_readiness, :bug_analysis, :data_quality, :export]
  before_action :prepare_owner_role_filter, only: [:owner_returns, :owner_workload, :flow_report]

  helper :queries

  # ---------------------------------------------------------------
  # INDEX — list all issues with computed durations
  # ---------------------------------------------------------------
  def index
    @issues_data = compute_all_durations
    @report_sections = build_report_sections(@issues_data)
    load_issue_detail(params[:issue_id])
    @detail_view_active = params[:view].to_s == 'detail'
  end

  # ---------------------------------------------------------------
  # PMO CONTROL - executive project control snapshot
  # ---------------------------------------------------------------
  def pmo_control
    @data_quality_stale_days = data_quality_stale_days_param
    @pmo_control_report = compute_pmo_control_report
  end

  # ---------------------------------------------------------------
  # SPRINT DELIVERY - sprint commitment, completion, and carry-over
  # ---------------------------------------------------------------
  def sprint_delivery
    build_query_from(sprint_delivery_query_params)
    @sprint_options = sprint_delivery_sprints
    @selected_sprint = selected_sprint(@sprint_options)
    @sprint_delivery_report = compute_sprint_delivery_report(@selected_sprint)
  end

  # ---------------------------------------------------------------
  # OWNER RETURNS — summary of returned tickets by ticket owner
  # ---------------------------------------------------------------
  def owner_returns
    @issues_data = compute_all_durations
    @owner_return_rows = compute_owner_returns_summary(@issues_data, role_id: @selected_owner_role&.id)
  end

  # ---------------------------------------------------------------
  # OWNER WORKLOAD - current open workload by ticket owner
  # ---------------------------------------------------------------
  def owner_workload
    @owner_workload_rows, @owner_workload_totals = compute_owner_workload_report(role_id: @selected_owner_role&.id)
  end

  # ---------------------------------------------------------------
  # AGING / SLA RISK - current open issue age buckets and risk flags
  # ---------------------------------------------------------------
  def aging_risk
    @aging_group_by = aging_group_by_param
    @aging_risk_rows, @aging_risk_totals = compute_aging_risk_report(@aging_group_by)
  end

  # ---------------------------------------------------------------
  # PRIORITY / SLA RISK - urgent/immediate open ticket risk
  # ---------------------------------------------------------------
  def priority_risk
    @priority_risk_rows, @priority_owner_rows, @priority_risk_totals = compute_priority_risk_report
  end

  # ---------------------------------------------------------------
  # CYCLE DISTRIBUTION - completed ticket cycle time distribution
  # ---------------------------------------------------------------
  def cycle_distribution
    build_query_from(ActionController::Parameters.new(completed_status_query_params))
    @cycle_group_by = cycle_distribution_group_by_param
    @issues_data = compute_all_durations
    @cycle_distribution_rows, @cycle_distribution_totals, @cycle_slowest_items = compute_cycle_distribution_report(@issues_data, @cycle_group_by)
  end

  # ---------------------------------------------------------------
  # FLOW REPORT - status/tracker snapshot trend over a date range
  # ---------------------------------------------------------------
  def flow_report
    @flow_start_date, @flow_end_date = flow_period_dates
    @flow_dates = flow_snapshot_dates(@flow_start_date, @flow_end_date)
    @flow_issues = flow_report_issues
    @flow_status_rows = []
    @flow_tracker_rows = []
    @flow_return_reason_rows = []
    @flow_summary = { issues: 0, snapshots: @flow_dates.size, start_total: 0, end_total: 0 }

    if @query&.valid?
      @flow_status_rows, @flow_tracker_rows, @flow_summary = compute_flow_trends(@flow_issues, @flow_dates)
      @flow_return_reason_rows = compute_flow_return_reason_rows(@flow_issues)
    end
  end

  # ---------------------------------------------------------------
  # PROJECT HEALTH - high-level open ticket health snapshot
  # ---------------------------------------------------------------
  def project_health
    @project_health_report = compute_project_health_report
  end

  # ---------------------------------------------------------------
  # RELEASE READINESS - target version / release readiness snapshot
  # ---------------------------------------------------------------
  def release_readiness
    @release_readiness_report = compute_release_readiness_report
  end

  # ---------------------------------------------------------------
  # BUG ANALYSIS - periodic bug movement by bug source
  # ---------------------------------------------------------------
  def bug_analysis
    @bug_start_date, @bug_end_date = bug_analysis_period_dates
    @bug_analysis_rows, @bug_analysis_totals = compute_bug_analysis_report(@bug_start_date, @bug_end_date)
  end

  # ---------------------------------------------------------------
  # DATA QUALITY - ticket quality and data discipline snapshot
  # ---------------------------------------------------------------
  def data_quality
    @data_quality_stale_days = data_quality_stale_days_param
    @data_quality_report = compute_data_quality_report
  end

  # ---------------------------------------------------------------
  # SHOW — single issue detail
  # ---------------------------------------------------------------
  def show
    issue = Issue.includes(:status, :author, :assigned_to, :tracker).find(params[:id])
    return render_403 unless issue.project == @project

    redirect_to ticket_journey_path(@project, issue_id: issue.id, view: 'detail')
  end
  # ---------------------------------------------------------------
  # EXPORT — CSV download
  # ---------------------------------------------------------------
  def export
    @issues_data = compute_all_durations
    @report_sections = build_report_sections(@issues_data)
    respond_to do |format|
      format.csv do
        send_data generate_csv(@report_sections),
                  filename:     "ticket_journey_#{@project.identifier}_#{Date.today}.csv",
                  type:         'text/csv; charset=utf-8',
                  disposition:  'attachment'
      end
    end
  end

  private

  # ---------------------------------------------------------------
  # SPRINT DELIVERY helpers
  # ---------------------------------------------------------------
  def sprint_delivery_sprints
    sprint_tracker_ids = Tracker.where(name: ['Sprint']).pluck(:id)
    return [] if sprint_tracker_ids.empty?

    Issue.includes(:status, :tracker)
         .where(project_id: project_and_subproject_ids, tracker_id: sprint_tracker_ids)
         .order(Arel.sql("#{Issue.table_name}.id DESC"))
         .limit(50)
         .to_a
  end

  def sprint_delivery_query_params
    query_params = params.to_unsafe_h.deep_dup.deep_stringify_keys
    operators = (query_params['op'] || {}).deep_stringify_keys

    remove_query_param_filter(query_params, 'status_id') if operators['status_id'] == 'o'
    query_params
  end

  def remove_query_param_filter(query_params, field_name)
    filters = Array(query_params['f']).map(&:to_s)
    query_params['f'] = filters.reject { |filter| filter == field_name }
    query_params['op'] ||= {}
    query_params['v'] ||= {}
    query_params['op'].delete(field_name)
    query_params['v'].delete(field_name)
  end

  def selected_sprint(sprints)
    requested_id = params[:sprint_id].presence
    return sprints.find { |sprint| sprint.id == requested_id.to_i } if requested_id.present?

    sprints.find { |sprint| !sprint.status&.is_closed? } || sprints.first
  end

  def compute_sprint_delivery_report(sprint)
    empty_report = empty_sprint_delivery_report(sprint)
    return empty_report if sprint.nil? || !@query&.valid?

    issues = sprint_related_issues(sprint)
    issues = apply_sprint_delivery_query_filters(issues) if sprint_delivery_query_filter_active?
    issues = issues.reject { |issue| issue.id == sprint.id || issue.tracker&.name.to_s == 'Sprint' }
                   .sort_by { |issue| [issue.due_date || Date.new(9999, 12, 31), issue.start_date || Date.new(9999, 12, 31), issue.id] }

    totals = sprint_delivery_totals(sprint, issues)
    status_rows = sprint_delivery_status_rows(issues)
    owner_rows = sprint_delivery_owner_rows(sprint, issues)
    issue_rows = sprint_delivery_issue_rows(sprint, issues)

    empty_report.merge(
      issues: issues,
      issue_rows: issue_rows,
      totals: totals,
      status_rows: status_rows,
      owner_rows: owner_rows,
      health: sprint_delivery_health(totals)
    )
  end

  def empty_sprint_delivery_report(sprint)
    {
      sprint: sprint,
      issues: [],
      totals: {
        committed: 0,
        completed: 0,
        not_delivered: 0,
        completion_rate: 0.0,
        carry_over: 0,
        carry_over_rate: 0.0,
        current_scope: 0,
        stopped: 0,
        not_started: 0,
        returned: 0,
        overdue: 0,
        technical_debt: 0
      },
      issue_rows: [],
      status_rows: [],
      owner_rows: [],
      health: { label: 'No Sprint', tone: :dim, note: 'No Sprint tracker issue was found for this project.' }
    }
  end

  def sprint_related_issues(sprint)
    relations = IssueRelation.where(issue_from_id: sprint.id)
                             .or(IssueRelation.where(issue_to_id: sprint.id))

    related_ids = relations.flat_map do |relation|
      [relation.issue_from_id, relation.issue_to_id]
    end.uniq - [sprint.id]

    return [] if related_ids.empty?

    Issue.includes(:status, :tracker, :priority, :assigned_to, :fixed_version, { custom_values: :custom_field })
         .where(id: related_ids, project_id: project_and_subproject_ids)
         .to_a
  end

  def sprint_delivery_query_filter_active?
    query_params = sprint_delivery_query_params
    return true if query_params['query_id'].present?

    Array(query_params['f']).map(&:to_s).reject(&:blank?).any?
  end

  def apply_sprint_delivery_query_filters(issues)
    return issues unless @query&.valid?

    filtered_ids = @query.issues(include: []).map(&:id)
    issues.select { |issue| filtered_ids.include?(issue.id) }
  end

  def sprint_delivery_totals(sprint, issues)
    committed = issues.size
    completed = issues.count { |issue| completed_sprint_status?(issue.status&.name) }
    stopped = issues.count { |issue| paused_status?(issue.status&.name) }
    not_started = issues.count { |issue| not_started_sprint_status?(issue.status&.name) }
    returned = issues.count { |issue| status_role(issue.status&.name) == :returned }
    overdue = issues.count { |issue| sprint_delivery_overdue?(issue) }
    carry_over = issues.count { |issue| carry_over_sprint_issue?(sprint, issue) }
    technical_debt = issues.count { |issue| carry_over_sprint_issue?(sprint, issue) && !completed_sprint_status?(issue.status&.name) }

    {
      committed: committed,
      completed: completed,
      not_delivered: committed - completed,
      completion_rate: ratio(completed, committed),
      carry_over: carry_over,
      carry_over_rate: ratio(carry_over, committed),
      current_scope: committed - carry_over,
      stopped: stopped,
      not_started: not_started,
      returned: returned,
      overdue: overdue,
      technical_debt: technical_debt
    }
  end

  def sprint_delivery_status_rows(issues)
    status_counts = issues.group_by { |issue| issue.status&.name.to_s.presence || 'No Status' }
                          .transform_values(&:size)
    total = issues.size

    FLOW_STATUS_ORDER.map do |status_name|
      count = status_counts.delete(status_name).to_i
      {
        status: status_name,
        group: sprint_delivery_status_group(status_name),
        count: count,
        percent: ratio(count, total),
        separator_before: FLOW_STATUS_SEPARATOR_BEFORE.include?(status_name)
      }
    end.select { |row| row[:count].positive? || sprint_delivery_core_status?(row[:status]) } +
      status_counts.sort_by { |status_name, _count| status_name.downcase }.map do |status_name, count|
        {
          status: status_name,
          group: 'Other',
          count: count,
          percent: ratio(count, total),
          separator_before: false
        }
      end
  end

  def sprint_delivery_owner_rows(sprint, issues)
    total = issues.size
    rows = issues.group_by { |issue| ticket_owner_info(issue) }
                 .map do |(owner_value, owner_name), owner_issues|
      completed = owner_issues.count { |issue| completed_sprint_status?(issue.status&.name) }
      {
        owner_value: owner_value,
        owner: owner_name.presence || 'No Ticket Owner',
        committed: owner_issues.size,
        completed: completed,
        completion_rate: ratio(completed, owner_issues.size),
        not_started: owner_issues.count { |issue| not_started_sprint_status?(issue.status&.name) },
        stopped: owner_issues.count { |issue| paused_status?(issue.status&.name) },
        returned: owner_issues.count { |issue| status_role(issue.status&.name) == :returned },
        overdue: owner_issues.count { |issue| sprint_delivery_overdue?(issue) },
        carry_over: owner_issues.count { |issue| carry_over_sprint_issue?(sprint, issue) },
        share: ratio(owner_issues.size, total)
      }
    end

    rows.sort_by { |row| [-row[:committed], -row[:stopped], -row[:overdue], row[:owner].to_s.downcase] }
  end

  def sprint_delivery_issue_rows(sprint, issues)
    issues.map do |issue|
      owner_value, owner_name = ticket_owner_info(issue)
      flags = []
      flags << 'Carry-over' if carry_over_sprint_issue?(sprint, issue)
      flags << 'Stopped' if paused_status?(issue.status&.name)
      flags << 'Overdue' if sprint_delivery_overdue?(issue)
      flags << 'Not Started' if not_started_sprint_status?(issue.status&.name)
      flags << 'Returned' if status_role(issue.status&.name) == :returned

      {
        issue: issue,
        owner_value: owner_value,
        owner: owner_name.presence || 'Unassigned',
        original_sprint: issue.custom_value_for(TICKET_ORIGINAL_SPRINT_CF_ID)&.value.presence || '-',
        flags: flags
      }
    end
  end

  def sprint_delivery_health(totals)
    if totals[:committed].to_i.zero?
      { label: 'No Scope', tone: :dim, note: 'The selected sprint has no related committed tickets.' }
    elsif totals[:stopped].to_i.positive? || totals[:overdue].to_i.positive?
      { label: 'Risk', tone: :red, note: 'Stopped or overdue sprint work needs PM/team follow-up.' }
    elsif totals[:carry_over].to_i.positive? || totals[:not_started].to_i.positive? || totals[:returned].to_i.positive?
      { label: 'Watch', tone: :orange, note: 'Sprint scope has carry-over, not-started, or returned work to monitor.' }
    else
      { label: 'Good', tone: :green, note: 'No stopped, overdue, returned, or carry-over signals were found.' }
    end
  end

  def sprint_delivery_status_group(status_name)
    case status_role(status_name)
    when :pending, :on_hold
      'Stopped'
    when :done, :archived
      'Done'
    else
      'WIP'
    end
  end

  def sprint_delivery_core_status?(status_name)
    FLOW_STATUS_ORDER.include?(status_name)
  end

  def completed_sprint_status?(status_name)
    %i[done archived].include?(status_role(status_name))
  end

  def not_started_sprint_status?(status_name)
    %i[new todo].include?(status_role(status_name))
  end

  def sprint_delivery_overdue?(issue)
    return false if completed_sprint_status?(issue.status&.name)
    return false if issue.due_date.blank?

    issue.due_date < User.current.today
  end

  def carry_over_sprint_issue?(sprint, issue)
    original_sprint = issue.custom_value_for(TICKET_ORIGINAL_SPRINT_CF_ID)&.value.to_s.strip
    return false if original_sprint.blank?

    return false if sprint_reference_matches?(sprint, original_sprint)

    true
  end

  def sprint_reference_matches?(sprint, original_sprint)
    original_normalized = normalize_sprint_reference(original_sprint)
    current_names = [
      sprint.id.to_s,
      "##{sprint.id}",
      sprint.subject.to_s
    ].map { |value| normalize_sprint_reference(value) }

    return true if current_names.include?(original_normalized)

    sprint_number = sprint_number_from(sprint.subject)
    return false if sprint_number.blank?
    return false unless sprint_number_from(original_sprint) == sprint_number

    sprint_prefix_matches?(sprint, original_sprint)
  end

  def normalize_sprint_reference(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, ' ').squish
  end

  def sprint_number_from(value)
    text = value.to_s.downcase
    text[/\bsprint\s*#?\s*(\d+)\b/, 1].presence || text[/\bs\s*(\d+)\b/, 1].presence
  end

  def sprint_prefix_matches?(sprint, original_sprint)
    subject_prefix = sprint.subject.to_s.split(/-\s*sprint/i).first.to_s
    normalized_prefix = normalize_sprint_reference(subject_prefix)
    return true if normalized_prefix.blank?

    original_normalized = normalize_sprint_reference(original_sprint)
    prefix_tokens = normalized_prefix.split
    prefix_aliases = [
      normalized_prefix,
      prefix_tokens.map { |token| token[0] }.join,
      prefix_tokens.first.to_s[0, 3]
    ].reject(&:blank?)

    prefix_aliases.any? { |prefix| original_normalized.start_with?(prefix) || original_normalized.include?(" #{prefix} ") }
  end

  # ---------------------------------------------------------------
  # PMO CONTROL helpers
  # ---------------------------------------------------------------
  def compute_pmo_control_report
    health_report = compute_project_health_report
    _aging_rows, aging_totals = compute_aging_risk_report('owner')
    priority_rows, _priority_owner_rows, priority_totals = compute_priority_risk_report
    owner_rows, owner_totals = compute_owner_workload_report
    release_report = compute_release_readiness_report
    data_quality_report = compute_data_quality_report
    bug_start_date, bug_end_date = bug_analysis_period_dates
    _bug_rows, bug_totals = compute_bug_analysis_report(bug_start_date, bug_end_date)

    {
      report_date: User.current.today,
      health: health_report,
      aging: aging_totals,
      priority: priority_totals,
      owner_workload: owner_totals,
      owner_attention_rows: owner_rows.first(8),
      priority_rows: priority_rows.first(8),
      release: release_report,
      release_attention_rows: pmo_release_attention_rows(release_report[:rows]),
      data_quality: data_quality_report,
      data_quality_field_rows: data_quality_report[:field_rows].select { |row| row[:count].to_i.positive? }.first(8),
      bug_period: [bug_start_date, bug_end_date],
      bug: bug_totals,
      overall_status: pmo_control_status(aging_totals, priority_totals, release_report, data_quality_report),
      kpis: pmo_control_kpis(health_report, aging_totals, priority_totals, release_report, data_quality_report, bug_totals),
      attention_items: pmo_control_attention_items(aging_totals, priority_totals, release_report, data_quality_report, bug_totals)
    }
  end

  def pmo_control_status(aging_totals, priority_totals, release_report, data_quality_report)
    data_totals = data_quality_report[:totals]

    risk_reasons = []
    risk_reasons << 'priority SLA risk exists' if priority_totals[:total_open].to_i.positive?
    risk_reasons << 'overdue tickets exist' if aging_totals[:overdue].to_i.positive?
    risk_reasons << 'stopped tickets exist' if aging_totals[:stopped].to_i.positive?
    risk_reasons << 'release risk exists' if release_report[:at_risk_versions].to_i.positive?
    risk_reasons << 'missing required data is high' if data_totals[:missing_required_percent].to_f >= 0.3

    return { label: 'Risk', tone: :red, note: risk_reasons.join(', ') } if risk_reasons.any?

    watch_reasons = []
    watch_reasons << '60d+ aging exists' if aging_totals[:bucket_60_plus].to_i.positive?
    watch_reasons << 'missing required data needs cleanup' if data_totals[:missing_required].to_i.positive?
    watch_reasons << 'stale updates exist' if data_totals[:tickets_without_updates].to_i.positive?

    return { label: 'Watch', tone: :orange, note: watch_reasons.join(', ') } if watch_reasons.any?

    { label: 'Good', tone: :green, note: 'No major PMO risk signals for the current filters' }
  end

  def pmo_control_kpis(health_report, aging_totals, priority_totals, release_report, data_quality_report, bug_totals)
    data_totals = data_quality_report[:totals]
    [
      { label: 'Total Open', value: health_report[:total_open], tone: :blue, help: 'All currently open tickets in the selected project scope.' },
      { label: 'Priority / SLA Risk', value: priority_totals[:total_open], tone: priority_totals[:total_open].to_i.positive? ? :red : :dim, help: 'Open Urgent or Immediate tickets.' },
      { label: 'Overdue', value: aging_totals[:overdue], tone: aging_totals[:overdue].to_i.positive? ? :red : :dim, help: 'Open tickets with due date before today.' },
      { label: 'Stopped', value: aging_totals[:stopped], tone: aging_totals[:stopped].to_i.positive? ? :red : :dim, help: 'Open tickets currently Pending or On-Hold.' },
      { label: '60d+ Open', value: aging_totals[:bucket_60_plus], tone: aging_totals[:bucket_60_plus].to_i.positive? ? :orange : :dim, help: 'Open tickets created more than 60 days ago.' },
      { label: 'Missing Required', value: pmo_percent_value(data_totals[:missing_required_percent]), tone: data_totals[:missing_required].to_i.positive? ? :red : :dim, help: 'Percent of open tickets missing at least one required planning field.' },
      { label: 'No Update', value: pmo_percent_value(data_totals[:tickets_without_updates_percent]), tone: data_totals[:tickets_without_updates].to_i.positive? ? :orange : :dim, help: 'Percent of open tickets not updated within the selected threshold.' },
      { label: 'Release Risk', value: release_report[:at_risk_versions], tone: release_report[:at_risk_versions].to_i.positive? ? :red : :dim, help: 'Target versions marked red by release readiness rules.' },
      { label: 'Remaining Bugs', value: bug_totals[:remaining], tone: bug_totals[:remaining].to_i.positive? ? :orange : :dim, help: 'Bug tracker tickets still open at the end of the selected bug period.' }
    ]
  end

  def pmo_control_attention_items(aging_totals, priority_totals, release_report, data_quality_report, bug_totals)
    data_totals = data_quality_report[:totals]
    items = [
      { label: 'Overdue open tickets', value: aging_totals[:overdue], tone: :red, path: :issues, scope: :overdue },
      { label: 'Stopped tickets', value: aging_totals[:stopped], tone: :red, path: :issues, scope: :stopped },
      { label: 'Urgent / Immediate open tickets', value: priority_totals[:total_open], tone: :red, path: :issues, scope: :priority_open },
      { label: 'Open tickets older than 60 days', value: aging_totals[:bucket_60_plus], tone: :orange, path: :issues, scope: :bucket_60_plus },
      { label: 'Tickets missing owner', value: data_totals[:missing_owner], tone: :red, path: :issues, scope: :missing_owner },
      { label: 'Tickets missing due date', value: data_totals[:missing_due_date], tone: :orange, path: :issues, scope: :missing_due_date },
      { label: 'Tickets without recent update', value: data_totals[:tickets_without_updates], tone: :orange, path: :issues, scope: :no_update },
      { label: 'At-risk releases', value: release_report[:at_risk_versions], tone: :red, path: :release_readiness },
      { label: 'Remaining bugs in selected period', value: bug_totals[:remaining], tone: :orange, path: :bug_analysis }
    ]

    items.select { |item| item[:value].to_i.positive? }
         .sort_by { |item| [-item[:value].to_i, item[:label]] }
         .first(8)
  end

  def pmo_release_attention_rows(rows)
    rows.select { |row| %i[red amber].include?(row[:risk]) }
        .sort_by { |row| [row[:risk] == :red ? 0 : 1, row[:due_date] || Date.new(9999, 12, 31), -row[:open].to_i, row[:name].to_s.downcase] }
        .first(8)
  end

  def pmo_percent_value(value)
    "#{(value.to_f * 100).round(1)}%"
  end

  # ---------------------------------------------------------------
  # FIND PROJECT (standard Redmine pattern)
  # ---------------------------------------------------------------
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def build_query
    build_query_from(params)
  end

  def build_query_from(query_params)
    base_query =
      if query_params[:query_id].present? || query_params['query_id'].present?
        IssueQuery.visible.where(project_id: [nil, @project.id]).find_by(id: query_params[:query_id] || query_params['query_id'])
      else
        IssueQuery.default(project: @project, user: User.current)
      end

    @query = (base_query || IssueQuery.new(name: '_'))
    @query.project = @project
    @query.build_from_params(query_params, project: @project)

    unless query_params[:query_id].present? || query_params['query_id'].present? || query_params[:c].present? || query_params['c'].present? || query_params.dig(:query, :column_names).present? || query_params.dig('query', 'column_names').present?
      @query.column_names = [:id, :subject, :status, "cf_#{TICKET_OWNER_CF_ID}"]
    end
  end

  def completed_status_query_params
    query_params = params.to_unsafe_h.deep_dup.deep_stringify_keys
    filters = Array(query_params['f']).map(&:to_s)
    operators = (query_params['op'] || {}).deep_dup.deep_stringify_keys
    values = (query_params['v'] || {}).deep_dup.deep_stringify_keys

    filters.delete('status_id')
    operators.delete('status_id')
    values.delete('status_id')

    filters << 'status_id'
    operators['status_id'] = 'c'
    values['status_id'] = ['']
    query_params['set_filter'] = '1'
    query_params['f'] = filters
    query_params['op'] = operators
    query_params['v'] = values
    query_params
  end

  def project_and_subproject_ids
    @project_and_subproject_ids ||= @project.self_and_descendants.pluck(:id)
  end

  def load_issue_detail(issue_id)
    return if issue_id.blank?

    @detail_issue_id = issue_id.to_s
    @issue = Issue.includes(:status, :author, :assigned_to, :tracker).find_by(id: issue_id)
    if @issue.nil?
      @detail_issue_error = "Issue ##{issue_id} was not found."
      return
    end

    unless project_and_subproject_ids.include?(@issue.project_id)
      @detail_issue_error = "Issue ##{issue_id} does not belong to this project."
      @issue = nil
      return
    end

    @tracker_family_key = tracker_family_for_issue(@issue)
    @duration_data = compute_issue_durations(@issue)
    @transitions = load_transitions(@issue)[@issue.id] || []
    @status_change_count = @transitions.count { |transition| !transition[:synthetic] }
    @assignment_periods = load_assignment_periods(@issue)
    @history_summary_until = terminal_time_for_periods(@duration_data[:periods] || [])
    status_summary_periods = clipped_periods(@duration_data[:periods] || [], @history_summary_until, exclude_terminal: true)
    assignment_summary_periods = clipped_periods(@assignment_periods, @history_summary_until)
    assignment_summary_periods = remove_pause_time_from_periods(
      assignment_summary_periods,
      pause_periods_for_summary(status_summary_periods, @tracker_family_key)
    )
    @history_summary_total = status_summary_periods.sum { |period| period_hours(period) }
    @status_time_summary = summarize_named_periods(status_summary_periods, :status)
    @assignment_time_summary = summarize_named_periods(assignment_summary_periods, :assignee)
  end

  def prepare_owner_role_filter
    @owner_roles = Role.joins(member_roles: :member)
                       .where(members: { project_id: project_and_subproject_ids })
                       .distinct
                       .order(:position, :name)

    requested_role_id = params[:ticket_owner_role_id].presence
    @selected_owner_role =
      if requested_role_id == 'all'
        nil
      elsif requested_role_id.present?
        @owner_roles.find { |role| role.id == requested_role_id.to_i }
      else
        @owner_roles.find { |role| role.name.casecmp('Developer').zero? }
      end

    @selected_owner_role_option = requested_role_id == 'all' ? 'all' : @selected_owner_role&.id
  end

  # ---------------------------------------------------------------
  # STATUS NAME CONFIGURATION
  # ---------------------------------------------------------------
  STATUS_NAMES = {
    new:          ['New'],
    todo:         ['To-Do'],
    returned:     ['Returned'],
    in_progress:  ['In Progress', 'Inprogress'],
    feedback:     ['Feedback'],
    review:       ['Review'],
    pending:      ['Pending'],
    ready_merge:  ['Ready to Merge'],
    final_check:  ['Final Check'],
    on_hold:      ['On-Hold'],
    ongoing:      ['Ongoing'],
    archived:     ['Archived'],
    done:         ['Done / Closed'],
  }.freeze

  def status_role(status_name)
    return :unknown if status_name.nil?
    n = status_name.to_s.downcase.strip
    STATUS_NAMES.each do |role, names|
      return role if names.any? { |sn| sn.downcase == n }
    end
    :unknown
  end

  def tracker_family_for_issue(issue)
    tracker_name = issue.tracker&.name.to_s

    TRACKER_FAMILY_DEFINITIONS.each do |family_key, definition|
      return family_key if definition[:tracker_names].include?(tracker_name)
    end

    :internal
  end

  # ---------------------------------------------------------------
  # LOAD TRANSITIONS for a set of issues (or single issue)
  # ---------------------------------------------------------------
  def load_transitions(scope_or_issue)
    if scope_or_issue.is_a?(Issue)
      issues_list = [scope_or_issue]
    elsif scope_or_issue.is_a?(Array)
      issues_list = scope_or_issue
    else
      issues_list = scope_or_issue.to_a
    end

    issue_ids = issues_list.map(&:id)
    return {} if issue_ids.empty?

    rows = ActiveRecord::Base.connection.select_all(<<~SQL)
      SELECT
        i.id                AS issue_id,
        i.subject           AS issue_subject,
        i.created_on        AS issue_created_on,
        j.created_on        AS changed_at,
        j.notes             AS notes,
        s_from.name         AS from_status,
        s_to.name           AS to_status,
        u.login             AS changed_by,
        u.firstname         AS changed_by_firstname,
        u.lastname          AS changed_by_lastname
      FROM issues i
      JOIN journals j
        ON j.journalized_id   = i.id
        AND j.journalized_type = 'Issue'
      JOIN journal_details jd
        ON jd.journal_id = j.id
        AND jd.property  = 'attr'
        AND jd.prop_key  = 'status_id'
      LEFT JOIN issue_statuses s_from ON s_from.id = CAST(jd.old_value AS UNSIGNED)
      LEFT JOIN issue_statuses s_to   ON s_to.id   = CAST(jd.value AS UNSIGNED)
      LEFT JOIN users u ON u.id = j.user_id
      WHERE i.id IN (#{issue_ids.join(',')})
      ORDER BY i.id, j.created_on ASC
    SQL

    by_issue = Hash.new { |h, k| h[k] = [] }
    rows_by_issue = rows.group_by { |row| row['issue_id'].to_i }

    issues_list.each do |iss|
      issue_rows = rows_by_issue[iss.id] || []
      first_row = issue_rows.first

      initial_status =
        if first_row && first_row['from_status'].present?
          first_row['from_status']
        elsif first_row && first_row['to_status'].present?
          first_row['to_status']
        else
          iss.status.name
        end

      by_issue[iss.id] << {
        issue_id: iss.id,
        issue_subject: iss.subject,
        changed_at: iss.created_on,
        from_status: nil,
        to_status: initial_status,
        changed_by: iss.author&.login,
        changed_by_name: iss.author&.name,
        notes: nil,
        synthetic: true
      }

      issue_rows.each do |row|
        by_issue[iss.id] << {
          issue_id: iss.id,
          issue_subject: row['issue_subject'],
          changed_at: row['changed_at'].is_a?(String) ? Time.parse(row['changed_at']) : row['changed_at'],
          from_status: row['from_status'],
          to_status: row['to_status'],
          changed_by: row['changed_by'],
          changed_by_name: "#{row['changed_by_firstname']} #{row['changed_by_lastname']}".strip,
          notes: row['notes'],
          synthetic: false
        }
      end
    end

    by_issue
  end
  # ---------------------------------------------------------------
  # COMPUTE DURATIONS FOR ALL ISSUES
  # ---------------------------------------------------------------
  def compute_all_durations
    return [] unless @query&.valid?

    issues = @query.issues(
      order: @query.sort_clause.presence || "#{Issue.table_name}.id DESC",
      include: [:status, :author, :assigned_to, :tracker, :priority, { custom_values: :custom_field }]
    )
    all_transitions = load_transitions(issues)

    issues.map do |issue|
      family_key = tracker_family_for_issue(issue)
      transitions = all_transitions[issue.id] || []
      durations = calculate_durations_for_family(family_key, transitions)

      {
        issue: issue,
        family_key: family_key,
        durations: durations
      }
    end
  end

  def compute_project_health_report
    issues = project_health_issues
    open_issues = issues.reject { |issue| issue.status&.is_closed? }

    technical_issues = open_issues.select { |issue| technical_tracker?(issue.tracker&.name) }
    planned_issues = open_issues.select { |issue| planned_work_issue?(issue) }
    task_issues = open_issues.select { |issue| task_tracker?(issue.tracker&.name) }
    milestone_issues = open_issues.select { |issue| milestone_tracker?(issue.tracker&.name) }

    {
      report_date: User.current.today,
      project_count: project_and_subproject_ids.size,
      total_open: open_issues.size,
      technical: technical_health_block(technical_issues),
      planned: planned_health_block(planned_issues),
      tasks: task_health_block(task_issues),
      milestones: milestone_health_block(milestone_issues)
    }
  end

  def project_health_issues
    Issue.includes(:status, :tracker, { custom_values: :custom_field })
         .where(project_id: project_and_subproject_ids)
         .references(:status, :tracker)
  end

  def compute_owner_workload_report(role_id: nil)
    return [[], empty_owner_workload_totals] unless @query&.valid?

    today = User.current.today
    allowed_owner_values = ticket_owner_values_for_role(role_id)
    issues = owner_workload_issues.reject do |issue|
      owner_value, = ticket_owner_info(issue)
      allowed_owner_values && !allowed_owner_values.include?(owner_value.to_s)
    end

    rows = Hash.new do |hash, owner_key|
      owner_value, owner_name = owner_key
      hash[owner_key] = {
        owner_value: owner_value,
        owner: owner_name,
        total_open: 0,
        technical_open: 0,
        task_open: 0,
        stopped: 0,
        overdue: 0,
        priority_open: 0,
        no_due_date: 0,
        age_sum: 0,
        oldest_age: 0,
        avg_age: 0.0
      }
    end

    issues.each do |issue|
      owner_value, owner_name = ticket_owner_info(issue)
      row = rows[[owner_value, owner_name]]
      age_days = [(today - issue.created_on.to_date).to_i, 0].max

      row[:total_open] += 1
      row[:technical_open] += 1 if technical_tracker?(issue.tracker&.name)
      row[:task_open] += 1 if task_tracker?(issue.tracker&.name)
      row[:stopped] += 1 if paused_status?(issue.status&.name)
      row[:overdue] += 1 if issue.due_date.present? && issue.due_date < today
      row[:priority_open] += 1 if priority_performance_ticket?(issue)
      row[:no_due_date] += 1 if issue.due_date.blank?
      row[:age_sum] += age_days
      row[:oldest_age] = [row[:oldest_age], age_days].max
    end

    owner_rows = rows.values.map do |row|
      row[:avg_age] = row[:total_open].positive? ? row[:age_sum].to_f / row[:total_open] : 0.0
      row
    end

    totals = {
      owners: owner_rows.size,
      total_open: owner_rows.sum { |row| row[:total_open] },
      stopped: owner_rows.sum { |row| row[:stopped] },
      overdue: owner_rows.sum { |row| row[:overdue] },
      priority_open: owner_rows.sum { |row| row[:priority_open] }
    }

    [sort_owner_workload_rows(owner_rows), totals]
  end

  def empty_owner_workload_totals
    { owners: 0, total_open: 0, stopped: 0, overdue: 0, priority_open: 0 }
  end

  def owner_workload_issues
    @query.issues(
      order: "#{Issue.table_name}.id ASC",
      include: [:status, :tracker, :priority, { custom_values: :custom_field }]
    ).reject { |issue| issue.status&.is_closed? }
  end

  def compute_aging_risk_report(group_by)
    return [[], empty_aging_risk_totals] unless @query&.valid?

    today = User.current.today
    rows = Hash.new do |hash, group_key|
      group_value, group_label = group_key
      hash[group_key] = empty_aging_risk_row(group_by, group_value, group_label)
    end

    aging_risk_issues.each do |issue|
      group_value, group_label = aging_group_value(issue, group_by)
      row = rows[[group_value, group_label]]
      age_days = [(today - issue.created_on.to_date).to_i, 0].max
      bucket_key = aging_bucket_key(age_days)

      row[:total_open] += 1
      row[bucket_key] += 1 if bucket_key
      row[:stopped] += 1 if paused_status?(issue.status&.name)
      row[:overdue] += 1 if issue.due_date.present? && issue.due_date < today
      row[:priority_open] += 1 if priority_performance_ticket?(issue)
      row[:no_due_date] += 1 if issue.due_date.blank?
      row[:age_sum] += age_days
      row[:oldest_age] = [row[:oldest_age], age_days].max
    end

    report_rows = rows.values.map do |row|
      row[:avg_age] = row[:total_open].positive? ? row[:age_sum].to_f / row[:total_open] : 0.0
      row
    end

    totals = aging_risk_totals(report_rows)
    [sort_aging_risk_rows(report_rows), totals]
  end

  def aging_risk_issues
    @query.issues(
      order: "#{Issue.table_name}.id ASC",
      include: [:status, :tracker, :priority, { custom_values: :custom_field }]
    ).reject { |issue| issue.status&.is_closed? }
  end

  def empty_aging_risk_row(group_by, group_value, group_label)
    {
      group_by: group_by,
      group_value: group_value,
      group: group_label,
      total_open: 0,
      bucket_0_7: 0,
      bucket_8_14: 0,
      bucket_15_30: 0,
      bucket_31_60: 0,
      bucket_60_plus: 0,
      stopped: 0,
      overdue: 0,
      priority_open: 0,
      no_due_date: 0,
      age_sum: 0,
      avg_age: 0.0,
      oldest_age: 0
    }
  end

  def empty_aging_risk_totals
    {
      groups: 0,
      total_open: 0,
      bucket_0_7: 0,
      bucket_8_14: 0,
      bucket_15_30: 0,
      bucket_31_60: 0,
      bucket_60_plus: 0,
      stopped: 0,
      overdue: 0,
      priority_open: 0,
      no_due_date: 0,
      avg_age: 0.0,
      oldest_age: 0
    }
  end

  def aging_risk_totals(rows)
    totals = empty_aging_risk_totals
    totals[:groups] = rows.size
    %i[total_open bucket_0_7 bucket_8_14 bucket_15_30 bucket_31_60 bucket_60_plus stopped overdue priority_open no_due_date].each do |key|
      totals[key] = rows.sum { |row| row[key].to_i }
    end

    age_sum = rows.sum { |row| row[:age_sum].to_i }
    totals[:avg_age] = totals[:total_open].positive? ? age_sum.to_f / totals[:total_open] : 0.0
    totals[:oldest_age] = rows.map { |row| row[:oldest_age].to_i }.max.to_i
    totals
  end

  def aging_group_by_param
    group_by = params[:aging_group_by].to_s
    AGING_RISK_GROUP_OPTIONS.key?(group_by) ? group_by : 'owner'
  end

  def aging_group_value(issue, group_by)
    case group_by
    when 'tracker'
      [issue.tracker_id, issue.tracker&.name.presence || 'No Tracker']
    when 'status'
      [issue.status_id, issue.status&.name.presence || 'No Status']
    when 'priority'
      [issue.priority_id, issue.priority&.name.presence || 'No Priority']
    else
      ticket_owner_info(issue)
    end
  end

  def aging_bucket_key(age_days)
    AGING_BUCKETS.find do |bucket|
      age_days >= bucket[:min] && (bucket[:max].nil? || age_days <= bucket[:max])
    end&.dig(:key)
  end

  def sort_aging_risk_rows(rows)
    sort_key = params[:aging_sort].to_s
    return default_aging_risk_sort(rows) unless AGING_RISK_SORTABLE_FIELDS.include?(sort_key)

    if sort_key == 'group'
      sorted_rows = rows.sort_by { |row| [row[:group].to_s.downcase, -row[:total_open].to_i] }
      return aging_risk_sort_direction(sort_key) == 'desc' ? sorted_rows.reverse : sorted_rows
    end

    direction_factor = aging_risk_sort_direction(sort_key) == 'asc' ? 1 : -1
    rows.sort_by do |row|
      [
        direction_factor * row[sort_key.to_sym].to_f,
        -row[:bucket_60_plus].to_i,
        -row[:bucket_31_60].to_i,
        -row[:overdue].to_i,
        -row[:total_open].to_i,
        row[:group].to_s.downcase
      ]
    end
  end

  def default_aging_risk_sort(rows)
    rows.sort_by do |row|
      [
        -row[:bucket_60_plus].to_i,
        -row[:bucket_31_60].to_i,
        -row[:overdue].to_i,
        -row[:stopped].to_i,
        -row[:total_open].to_i,
        row[:group].to_s.downcase
      ]
    end
  end

  def aging_risk_sort_direction(sort_key)
    requested_dir = params[:aging_dir].to_s
    return requested_dir if %w[asc desc].include?(requested_dir)

    sort_key == 'group' ? 'asc' : 'desc'
  end

  def compute_priority_risk_report
    return [[], [], empty_priority_risk_totals] unless @query&.valid?

    today = User.current.today
    rows = priority_risk_issues.filter_map do |issue|
      next unless priority_performance_ticket?(issue)

      owner_value, owner_name = ticket_owner_info(issue)
      due_date = issue.due_date
      age_days = [(today - issue.created_on.to_date).to_i, 0].max

      {
        issue: issue,
        issue_id: issue.id,
        subject: issue.subject,
        owner_value: owner_value,
        owner: owner_name,
        priority_id: issue.priority_id,
        priority: issue.priority&.name.presence || '-',
        status_id: issue.status_id,
        status: issue.status&.name.presence || '-',
        tracker_id: issue.tracker_id,
        tracker: issue.tracker&.name.presence || '-',
        due_date: due_date,
        age_days: age_days,
        overdue: due_date.present? && due_date < today,
        stopped: paused_status?(issue.status&.name),
        no_due_date: due_date.blank?
      }
    end

    owner_rows = priority_owner_rows(rows)
    totals = priority_risk_totals(rows, owner_rows)
    [sort_priority_risk_rows(rows), owner_rows, totals]
  end

  def priority_risk_issues
    @query.issues(
      order: "#{Issue.table_name}.id ASC",
      include: [:status, :tracker, :priority, { custom_values: :custom_field }]
    ).reject { |issue| issue.status&.is_closed? }
  end

  def priority_owner_rows(rows)
    grouped = rows.group_by { |row| [row[:owner_value], row[:owner]] }

    grouped.map do |(owner_value, owner_name), owner_issues|
      {
        owner_value: owner_value,
        owner: owner_name,
        total_open: owner_issues.size,
        overdue: owner_issues.count { |row| row[:overdue] },
        stopped: owner_issues.count { |row| row[:stopped] },
        no_due_date: owner_issues.count { |row| row[:no_due_date] },
        oldest_age: owner_issues.map { |row| row[:age_days].to_i }.max.to_i
      }
    end.sort_by { |row| [-row[:overdue].to_i, -row[:stopped].to_i, -row[:total_open].to_i, row[:owner].to_s.downcase] }
  end

  def priority_risk_totals(rows, owner_rows)
    return empty_priority_risk_totals if rows.empty?

    {
      owners: owner_rows.size,
      total_open: rows.size,
      overdue: rows.count { |row| row[:overdue] },
      stopped: rows.count { |row| row[:stopped] },
      no_due_date: rows.count { |row| row[:no_due_date] },
      avg_age: rows.sum { |row| row[:age_days].to_i }.to_f / rows.size,
      oldest_age: rows.map { |row| row[:age_days].to_i }.max.to_i
    }
  end

  def empty_priority_risk_totals
    {
      owners: 0,
      total_open: 0,
      overdue: 0,
      stopped: 0,
      no_due_date: 0,
      avg_age: 0.0,
      oldest_age: 0
    }
  end

  def sort_priority_risk_rows(rows)
    sort_key = params[:priority_sort].to_s
    return default_priority_risk_sort(rows) unless PRIORITY_RISK_SORTABLE_FIELDS.include?(sort_key)

    direction = priority_risk_sort_direction(sort_key)
    if %w[issue subject owner priority status tracker due_date].include?(sort_key)
      sorted_rows = rows.sort_by do |row|
        [
          priority_risk_sort_comparable(row, sort_key),
          row[:overdue] ? -1 : 0,
          row[:stopped] ? -1 : 0,
          -row[:age_days].to_i,
          row[:issue_id].to_i
        ]
      end
      return direction == 'desc' ? sorted_rows.reverse : sorted_rows
    end

    direction_factor = direction == 'asc' ? 1 : -1
    rows.sort_by do |row|
      [
        direction_factor * priority_risk_sort_numeric_value(row, sort_key),
        row[:overdue] ? -1 : 0,
        row[:stopped] ? -1 : 0,
        -row[:age_days].to_i,
        row[:issue_id].to_i
      ]
    end
  end

  def default_priority_risk_sort(rows)
    rows.sort_by do |row|
      [
        row[:due_date] || Date.new(9999, 12, 31),
        row[:overdue] ? -1 : 0,
        row[:stopped] ? -1 : 0,
        -row[:age_days].to_i,
        row[:owner].to_s.downcase,
        row[:issue_id].to_i
      ]
    end
  end

  def priority_risk_sort_comparable(row, sort_key)
    return row[:issue_id].to_i if sort_key == 'issue'
    return row[:due_date] || Date.new(9999, 12, 31) if sort_key == 'due_date'

    row[sort_key.to_sym].to_s.downcase
  end

  def priority_risk_sort_numeric_value(row, sort_key)
    case sort_key
    when 'overdue', 'stopped', 'no_due_date'
      row[sort_key.to_sym] ? 1 : 0
    else
      row[sort_key.to_sym].to_f
    end
  end

  def priority_risk_sort_direction(sort_key)
    requested_dir = params[:priority_dir].to_s
    return requested_dir if %w[asc desc].include?(requested_dir)

    %w[issue subject owner priority status tracker due_date].include?(sort_key) ? 'asc' : 'desc'
  end

  def compute_cycle_distribution_report(issues_data, group_by)
    completed_items = issues_data.filter_map do |item|
      cycle_hours = completed_cycle_time_hours(item)
      next unless cycle_hours

      _owner_value, owner_name = ticket_owner_info(item[:issue])
      item.merge(cycle_hours: cycle_hours, ticket_owner: owner_name)
    end

    rows = Hash.new do |hash, group_key|
      group_value, group_label = group_key
      hash[group_key] = empty_cycle_distribution_row(group_by, group_value, group_label)
    end

    completed_items.each do |item|
      group_value, group_label = cycle_distribution_group_value(item, group_by)
      row = rows[[group_value, group_label]]
      cycle_hours = item[:cycle_hours].to_f
      bucket_key = cycle_distribution_bucket_key(cycle_hours)

      row[:completed_count] += 1
      row[bucket_key] += 1 if bucket_key
      row[:cycle_hours_sum] += cycle_hours

      next unless cycle_hours > row[:max_cycle_hours].to_f

      row[:max_cycle_hours] = cycle_hours
      row[:max_issue] = item[:issue]
    end

    row_values = rows.values.map do |row|
      row[:avg_cycle_hours] = row[:completed_count].positive? ? row[:cycle_hours_sum] / row[:completed_count] : 0.0
      row
    end

    totals = cycle_distribution_totals(row_values, completed_items)
    slowest_items = completed_items.sort_by { |item| [-item[:cycle_hours].to_f, item[:issue].id] }.first(20)

    [sort_cycle_distribution_rows(row_values), totals, slowest_items]
  end

  def cycle_distribution_group_by_param
    group_by = params[:cycle_group_by].to_s
    CYCLE_DISTRIBUTION_GROUP_OPTIONS.key?(group_by) ? group_by : 'family'
  end

  def cycle_distribution_group_value(item, group_by)
    issue = item[:issue]

    case group_by
    when 'owner'
      ticket_owner_info(issue)
    when 'tracker'
      [issue.tracker_id, issue.tracker&.name.presence || 'No Tracker']
    else
      family_key = item[:family_key]
      family_label = TRACKER_FAMILY_DEFINITIONS.fetch(family_key, { label: family_key.to_s.humanize })[:label]
      [family_key, family_label]
    end
  end

  def cycle_distribution_bucket_key(hours)
    CYCLE_DISTRIBUTION_BUCKETS.find do |bucket|
      hours >= bucket[:min_hours] && (bucket[:max_hours].nil? || hours < bucket[:max_hours])
    end&.dig(:key)
  end

  def empty_cycle_distribution_row(group_by, group_value, group_label)
    {
      group_by: group_by,
      group_value: group_value,
      group: group_label,
      completed_count: 0,
      bucket_0_2: 0,
      bucket_3_7: 0,
      bucket_8_14: 0,
      bucket_15_30: 0,
      bucket_30_plus: 0,
      cycle_hours_sum: 0.0,
      avg_cycle_hours: 0.0,
      max_cycle_hours: 0.0,
      max_issue: nil
    }
  end

  def empty_cycle_distribution_totals
    {
      groups: 0,
      completed_count: 0,
      bucket_0_2: 0,
      bucket_3_7: 0,
      bucket_8_14: 0,
      bucket_15_30: 0,
      bucket_30_plus: 0,
      avg_cycle_hours: 0.0,
      max_cycle_hours: 0.0,
      max_issue: nil
    }
  end

  def cycle_distribution_totals(rows, completed_items)
    totals = empty_cycle_distribution_totals
    totals[:groups] = rows.size

    %i[completed_count bucket_0_2 bucket_3_7 bucket_8_14 bucket_15_30 bucket_30_plus].each do |key|
      totals[key] = rows.sum { |row| row[key].to_i }
    end

    cycle_hours_sum = completed_items.sum { |item| item[:cycle_hours].to_f }
    totals[:avg_cycle_hours] = totals[:completed_count].positive? ? cycle_hours_sum / totals[:completed_count] : 0.0

    max_item = completed_items.max_by { |item| item[:cycle_hours].to_f }
    totals[:max_cycle_hours] = max_item&.dig(:cycle_hours).to_f
    totals[:max_issue] = max_item&.dig(:issue)
    totals
  end

  def sort_cycle_distribution_rows(rows)
    sort_key = params[:cycle_sort].to_s
    return default_cycle_distribution_sort(rows) unless CYCLE_DISTRIBUTION_SORTABLE_FIELDS.include?(sort_key)

    if sort_key == 'group'
      sorted_rows = rows.sort_by { |row| [row[:group].to_s.downcase, -row[:completed_count].to_i] }
      return cycle_distribution_sort_direction(sort_key) == 'desc' ? sorted_rows.reverse : sorted_rows
    end

    direction_factor = cycle_distribution_sort_direction(sort_key) == 'asc' ? 1 : -1
    rows.sort_by do |row|
      [
        direction_factor * row[sort_key.to_sym].to_f,
        -row[:completed_count].to_i,
        -row[:avg_cycle_hours].to_f,
        row[:group].to_s.downcase
      ]
    end
  end

  def default_cycle_distribution_sort(rows)
    rows.sort_by { |row| [-row[:completed_count].to_i, -row[:avg_cycle_hours].to_f, row[:group].to_s.downcase] }
  end

  def cycle_distribution_sort_direction(sort_key)
    requested_dir = params[:cycle_dir].to_s
    return requested_dir if %w[asc desc].include?(requested_dir)

    sort_key == 'group' ? 'asc' : 'desc'
  end

  def sort_owner_workload_rows(rows)
    sort_key = params[:workload_sort].to_s
    return rows.sort_by { |row| [-row[:total_open], -row[:stopped], -row[:overdue], row[:owner].to_s.downcase] } unless OWNER_WORKLOAD_SORTABLE_FIELDS.include?(sort_key)

    if sort_key == 'owner'
      sorted_rows = rows.sort_by { |row| [row[:owner].to_s.downcase, -row[:total_open].to_i] }
      return owner_workload_sort_direction(sort_key) == 'desc' ? sorted_rows.reverse : sorted_rows
    end

    direction_factor = owner_workload_sort_direction(sort_key) == 'asc' ? 1 : -1
    rows.sort_by do |row|
      [
        owner_workload_sort_value(row, sort_key, direction_factor),
        -row[:total_open].to_i,
        row[:owner].to_s.downcase
      ]
    end
  end

  def owner_workload_sort_value(row, sort_key, direction_factor)
    direction_factor * row[sort_key.to_sym].to_f
  end

  def owner_workload_sort_direction(sort_key)
    requested_dir = params[:workload_dir].to_s
    return requested_dir if %w[asc desc].include?(requested_dir)

    sort_key == 'owner' ? 'asc' : 'desc'
  end

  def technical_health_block(issues)
    {
      title: 'Open Technical Tickets',
      note: 'Open Bug, Change Request / Improvement, and Feature tickets.',
      total: issues.size,
      rows: [
        health_metric('Backlog', issues.count { |issue| status_role(issue.status&.name) == :new }, issues.size),
        health_metric('Under Work', issues.count { |issue| active_work_status?(issue.status&.name) }, issues.size),
        health_metric('Stopped', issues.count { |issue| paused_status?(issue.status&.name) }, issues.size),
        health_metric('Ongoing', issues.count { |issue| status_role(issue.status&.name) == :ongoing }, issues.size)
      ]
    }
  end

  def planned_health_block(issues)
    {
      title: 'Open Planned Tickets Health',
      note: 'Open active non-container tickets; checks missing owner, start date, due date, and PM estimation.',
      total: issues.size,
      rows: [
        health_metric('Without Owner', issues.count { |issue| ticket_owner_info(issue).first.blank? }, issues.size),
        health_metric('Without Start Date', issues.count { |issue| issue.start_date.blank? }, issues.size),
        health_metric('Without Due Date', issues.count { |issue| issue.due_date.blank? }, issues.size),
        health_metric('Without PM Estimation', issues.count { |issue| issue.estimated_hours.blank? || issue.estimated_hours.to_f <= 0 }, issues.size)
      ]
    }
  end

  def task_health_block(issues)
    {
      title: 'Open Tasks (Business Jobs)',
      note: 'Open Task / Task (Business Jobs) tickets. Stopped means Pending or On-Hold.',
      total: issues.size,
      rows: [
        health_metric('To Do Tasks', issues.count { |issue| %i[new todo].include?(status_role(issue.status&.name)) }, issues.size),
        health_metric('Under Work Tasks', issues.count { |issue| active_work_status?(issue.status&.name) }, issues.size),
        health_metric('Stopped Tasks', issues.count { |issue| paused_status?(issue.status&.name) }, issues.size),
        health_metric('Ongoing Tasks', issues.count { |issue| status_role(issue.status&.name) == :ongoing }, issues.size)
      ]
    }
  end

  def milestone_health_block(issues)
    {
      title: 'Open Milestones',
      note: 'Open Milestone / Milestones tracker tickets. Stopped means Pending or On-Hold.',
      total: issues.size,
      rows: [
        health_metric('To-Do Milestones', issues.count { |issue| %i[new todo].include?(status_role(issue.status&.name)) }, issues.size),
        health_metric('In-Progress Milestones', issues.count { |issue| active_work_status?(issue.status&.name) }, issues.size),
        health_metric('Stopped Milestones', issues.count { |issue| paused_status?(issue.status&.name) }, issues.size)
      ]
    }
  end

  def health_metric(label, count, total)
    {
      label: label,
      count: count,
      percent: total.to_i.positive? ? (count.to_f / total.to_f) : 0.0
    }
  end

  def planned_work_issue?(issue)
    return false if container_tracker?(issue.tracker&.name)

    active_work_status?(issue.status&.name)
  end

  def active_work_status?(status_name)
    PROJECT_HEALTH_ACTIVE_STATUS_ROLES.include?(status_role(status_name))
  end

  def paused_status?(status_name)
    %i[pending on_hold].include?(status_role(status_name))
  end

  def technical_tracker?(tracker_name)
    TRACKER_FAMILY_DEFINITIONS.fetch(:internal).fetch(:tracker_names).include?(tracker_name.to_s)
  end

  def task_tracker?(tracker_name)
    TRACKER_FAMILY_DEFINITIONS.fetch(:task).fetch(:tracker_names).include?(tracker_name.to_s)
  end

  def container_tracker?(tracker_name)
    TRACKER_FAMILY_DEFINITIONS.fetch(:container).fetch(:tracker_names).include?(tracker_name.to_s)
  end

  def milestone_tracker?(tracker_name)
    %w[Milestone Milestones].include?(tracker_name.to_s)
  end

  def compute_release_readiness_report
    today = User.current.today
    issues = release_readiness_issues
    open_issues = issues.reject { |issue| issue.status&.is_closed? }
    versions = release_readiness_versions
    issues_by_version_id = issues.select(&:fixed_version_id).group_by(&:fixed_version_id)

    rows = versions.filter_map do |version|
      version_issues = issues_by_version_id.delete(version.id) || []
      next if version_issues.empty? && version.status.to_s == 'closed'

      release_readiness_row(version, version_issues, today)
    end

    rows += issues_by_version_id.filter_map do |version_id, version_issues|
      version = version_issues.first&.fixed_version
      version ? release_readiness_row(version, version_issues, today) : nil
    end

    rows = sort_release_readiness_rows(rows)
    no_target_open = open_issues.count { |issue| issue.fixed_version_id.blank? }

    {
      report_date: today,
      project_count: project_and_subproject_ids.size,
      versions: rows.size,
      total_assigned: rows.sum { |row| row[:total] },
      open_assigned: rows.sum { |row| row[:open] },
      ready_versions: rows.count { |row| row[:total].positive? && row[:open].zero? },
      at_risk_versions: rows.count { |row| row[:risk] == :red },
      no_target_open: no_target_open,
      rows: rows
    }
  end

  def release_readiness_issues
    Issue.includes(:status, :fixed_version, :priority, { custom_values: :custom_field })
         .where(project_id: project_and_subproject_ids)
  end

  def release_readiness_versions
    Version.includes(:project)
           .where(project_id: project_and_subproject_ids)
           .order(:effective_date, :name)
           .to_a
  end

  def release_readiness_row(version, issues, today)
    open_issues = issues.reject { |issue| issue.status&.is_closed? }
    closed_count = issues.size - open_issues.size
    done_percent = issues.any? ? (closed_count.to_f / issues.size.to_f) : 0.0
    past_release_date = version.effective_date.present? && version.effective_date < today
    due_soon = version.effective_date.present? && version.effective_date >= today && version.effective_date <= today + 14
    overdue_open = open_issues.count { |issue| issue.due_date.present? && issue.due_date < today }

    {
      id: version.id,
      name: version.name,
      project: version.project&.name,
      status: version.status.to_s.presence || '-',
      due_date: version.effective_date,
      total: issues.size,
      open: open_issues.size,
      done: closed_count,
      done_percent: done_percent,
      stopped: open_issues.count { |issue| paused_status?(issue.status&.name) },
      overdue: overdue_open,
      no_owner: open_issues.count { |issue| ticket_owner_info(issue).first.blank? },
      no_due_date: open_issues.count { |issue| issue.due_date.blank? },
      priority_open: open_issues.count { |issue| priority_performance_ticket?(issue) },
      past_release_date: past_release_date,
      due_soon: due_soon,
      risk: release_readiness_risk(open_issues.size, past_release_date, due_soon, overdue_open)
    }
  end

  def release_readiness_risk(open_count, past_release_date, due_soon, overdue_open)
    return :green if open_count.zero?
    return :red if past_release_date || overdue_open.positive?
    return :amber if due_soon

    :neutral
  end

  def sort_release_readiness_rows(rows)
    sort_key = params[:release_sort].to_s
    return default_release_readiness_sort(rows) unless RELEASE_READINESS_SORTABLE_FIELDS.include?(sort_key)

    direction = release_readiness_sort_direction(sort_key)
    if %w[name project status due_date].include?(sort_key)
      sorted = rows.sort_by do |row|
        [
          release_readiness_sort_comparable(row, sort_key),
          row[:due_date] || Date.new(9999, 12, 31),
          -row[:open].to_i,
          row[:name].to_s.downcase
        ]
      end
      return direction == 'desc' ? sorted.reverse : sorted
    end

    direction_factor = direction == 'asc' ? 1 : -1
    rows.sort_by do |row|
      [
        release_readiness_sort_value(row, sort_key, direction_factor),
        row[:due_date] || Date.new(9999, 12, 31),
        -row[:open].to_i,
        row[:name].to_s.downcase
      ]
    end
  end

  def default_release_readiness_sort(rows)
    rows.sort_by { |row| [row[:status] == 'closed' ? 1 : 0, row[:due_date] || Date.new(9999, 12, 31), -row[:open], row[:name].to_s.downcase] }
  end

  def release_readiness_sort_comparable(row, sort_key)
    return row[:due_date] || Date.new(9999, 12, 31) if sort_key == 'due_date'

    row[sort_key.to_sym].to_s.downcase
  end

  def release_readiness_sort_value(row, sort_key, direction_factor)
    case sort_key
    when 'risk'
      direction_factor * release_readiness_risk_sort_weight(row[:risk])
    else
      direction_factor * row[sort_key.to_sym].to_f
    end
  end

  def release_readiness_risk_sort_weight(risk)
    { red: 3, amber: 2, neutral: 1, green: 0 }.fetch(risk.to_sym, 0)
  end

  def release_readiness_sort_direction(sort_key)
    requested_dir = params[:release_dir].to_s
    return requested_dir if %w[asc desc].include?(requested_dir)

    %w[name project status due_date].include?(sort_key) ? 'asc' : 'desc'
  end

  def data_quality_stale_days_param
    days = params[:stale_days].to_i
    days.positive? ? days : DATA_QUALITY_DEFAULT_STALE_DAYS
  end

  def compute_data_quality_report
    return empty_data_quality_report unless @query&.valid?

    today = User.current.today
    issue_rows = data_quality_issues.map { |issue| data_quality_issue_row(issue, today) }
    totals = data_quality_totals(issue_rows)
    project_rows = issue_rows.group_by { |row| row[:project_id] }.map do |_project_id, rows|
      data_quality_project_row(rows, totals)
    end

    {
      report_date: today,
      stale_days: @data_quality_stale_days,
      totals: totals,
      project_rows: sort_data_quality_rows(project_rows),
      field_rows: data_quality_field_rows(totals),
      stale_rows: issue_rows.select { |row| row[:without_updates] }.sort_by { |row| [-row[:days_since_update].to_i, row[:project_name].to_s.downcase, row[:issue_id].to_i] }.first(150),
      missing_rows: issue_rows.select { |row| row[:missing_fields].any? }.sort_by { |row| [-row[:missing_fields].size, -row[:days_since_update].to_i, row[:project_name].to_s.downcase, row[:issue_id].to_i] }.first(150)
    }
  end

  def data_quality_issues
    @query.issues(
      order: "#{Issue.table_name}.id ASC",
      include: [:project, :status, :tracker, :priority, :fixed_version, { custom_values: :custom_field }]
    ).reject { |issue| issue.status&.is_closed? }
  end

  def data_quality_issue_row(issue, today)
    owner_value, owner_name = ticket_owner_info(issue)
    original_sprint = issue.custom_value_for(TICKET_ORIGINAL_SPRINT_CF_ID)&.value.presence
    days_since_update = issue.updated_on.present? ? [(today - issue.updated_on.to_date).to_i, 0].max : nil
    missing_fields = []
    missing_fields << 'Ticket Owner' if owner_value.blank?
    missing_fields << 'Start Date' if issue.start_date.blank?
    missing_fields << 'Due Date' if issue.due_date.blank?
    missing_fields << 'PM Estimation' if issue.estimated_hours.blank? || issue.estimated_hours.to_f <= 0
    missing_fields << 'Priority' if issue.priority_id.blank?
    missing_fields << 'Ticket Original Sprint' if original_sprint.blank?

    without_updates = days_since_update.present? && days_since_update >= @data_quality_stale_days

    {
      issue: issue,
      issue_id: issue.id,
      project: issue.project,
      project_id: issue.project_id,
      project_name: issue.project&.name || '-',
      subject: issue.subject,
      owner_value: owner_value,
      owner: owner_name,
      status: issue.status&.name || '-',
      priority: issue.priority&.name || '-',
      tracker: issue.tracker&.name || '-',
      sprint: original_sprint || issue.fixed_version&.name || '-',
      updated_on: issue.updated_on,
      days_since_update: days_since_update,
      missing_fields: missing_fields,
      missing_owner: owner_value.blank?,
      missing_start_date: issue.start_date.blank?,
      missing_due_date: issue.due_date.blank?,
      missing_estimation: issue.estimated_hours.blank? || issue.estimated_hours.to_f <= 0,
      missing_priority: issue.priority_id.blank?,
      missing_sprint: original_sprint.blank?,
      missing_required: missing_fields.any?,
      without_updates: without_updates,
      risk: data_quality_issue_risk(missing_fields.size, without_updates)
    }
  end

  def data_quality_issue_risk(missing_count, without_updates)
    return 'Risk' if missing_count >= 3 || (without_updates && missing_count.positive?)
    return 'Watch' if missing_count.positive? || without_updates

    'Good'
  end

  def data_quality_totals(issue_rows)
    total_active = issue_rows.size
    totals = {
      total_active: total_active,
      missing_required: issue_rows.count { |row| row[:missing_required] },
      tickets_without_updates: issue_rows.count { |row| row[:without_updates] },
      missing_owner: issue_rows.count { |row| row[:missing_owner] },
      missing_start_date: issue_rows.count { |row| row[:missing_start_date] },
      missing_due_date: issue_rows.count { |row| row[:missing_due_date] },
      missing_estimation: issue_rows.count { |row| row[:missing_estimation] },
      missing_priority: issue_rows.count { |row| row[:missing_priority] },
      missing_sprint: issue_rows.count { |row| row[:missing_sprint] }
    }

    totals[:missing_required_percent] = ratio(totals[:missing_required], total_active)
    totals[:tickets_without_updates_percent] = ratio(totals[:tickets_without_updates], total_active)
    totals[:missing_owner_percent] = ratio(totals[:missing_owner], total_active)
    totals[:missing_start_date_percent] = ratio(totals[:missing_start_date], total_active)
    totals[:missing_due_date_percent] = ratio(totals[:missing_due_date], total_active)
    totals[:missing_estimation_percent] = ratio(totals[:missing_estimation], total_active)
    totals[:missing_priority_percent] = ratio(totals[:missing_priority], total_active)
    totals[:missing_sprint_percent] = ratio(totals[:missing_sprint], total_active)
    totals
  end

  def data_quality_project_row(rows, totals)
    total_active = rows.size
    missing_required = rows.count { |row| row[:missing_required] }
    tickets_without_updates = rows.count { |row| row[:without_updates] }
    missing_required_percent = ratio(missing_required, total_active)
    no_update_percent = ratio(tickets_without_updates, total_active)
    reliability_status, reliability_rank = data_quality_reliability_status(missing_required_percent, no_update_percent)

    {
      project: rows.first[:project],
      project_id: rows.first[:project_id],
      project_name: rows.first[:project_name],
      total_active: total_active,
      total_active_percent: ratio(total_active, totals[:total_active]),
      missing_required: missing_required,
      missing_required_percent: missing_required_percent,
      tickets_without_updates: tickets_without_updates,
      no_update_percent: no_update_percent,
      missing_owner: rows.count { |row| row[:missing_owner] },
      missing_owner_percent: ratio(rows.count { |row| row[:missing_owner] }, total_active),
      missing_start_date: rows.count { |row| row[:missing_start_date] },
      missing_start_date_percent: ratio(rows.count { |row| row[:missing_start_date] }, total_active),
      missing_due_date: rows.count { |row| row[:missing_due_date] },
      missing_due_date_percent: ratio(rows.count { |row| row[:missing_due_date] }, total_active),
      missing_estimation: rows.count { |row| row[:missing_estimation] },
      missing_estimation_percent: ratio(rows.count { |row| row[:missing_estimation] }, total_active),
      missing_sprint: rows.count { |row| row[:missing_sprint] },
      missing_sprint_percent: ratio(rows.count { |row| row[:missing_sprint] }, total_active),
      reliability_status: reliability_status,
      reliability_rank: reliability_rank
    }
  end

  def data_quality_reliability_status(missing_required_percent, no_update_percent)
    worst_percent = [missing_required_percent, no_update_percent].max
    return ['Good', 0] if worst_percent <= 0.05
    return ['Watch', 1] if worst_percent <= 0.15

    ['Risk', 2]
  end

  def data_quality_field_rows(totals)
    [
      { key: :missing_owner, label: 'Missing Owner', scope: :missing_owner },
      { key: :missing_start_date, label: 'Missing Start Date', scope: :missing_start_date },
      { key: :missing_due_date, label: 'Missing Due Date', scope: :missing_due_date },
      { key: :missing_estimation, label: 'Missing PM Estimation', scope: :missing_estimation },
      { key: :missing_priority, label: 'Missing Priority', scope: :missing_priority },
      { key: :missing_sprint, label: 'Missing Original Sprint', scope: :missing_sprint },
      { key: :tickets_without_updates, label: "No Update #{@data_quality_stale_days}d+", scope: :no_update }
    ].map do |field|
      field.merge(count: totals[field[:key]].to_i, percent: ratio(totals[field[:key]].to_i, totals[:total_active]))
    end
  end

  def sort_data_quality_rows(rows)
    sort_key = params[:data_sort].to_s
    return rows.sort_by { |row| [-row[:reliability_rank].to_i, -row[:missing_required_percent].to_f, -row[:no_update_percent].to_f, -row[:total_active].to_i, row[:project_name].to_s.downcase] } unless DATA_QUALITY_SORTABLE_FIELDS.include?(sort_key)

    direction = data_quality_sort_direction(sort_key)
    if sort_key == 'project'
      sorted = rows.sort_by { |row| row[:project_name].to_s.downcase }
      return direction == 'desc' ? sorted.reverse : sorted
    end

    direction_factor = direction == 'asc' ? 1 : -1
    rows.sort_by do |row|
      [
        direction_factor * row[sort_key.to_sym].to_f,
        -row[:missing_required_percent].to_f,
        row[:project_name].to_s.downcase
      ]
    end
  end

  def data_quality_sort_direction(sort_key)
    requested_dir = params[:data_dir].to_s
    return requested_dir if %w[asc desc].include?(requested_dir)

    sort_key == 'project' ? 'asc' : 'desc'
  end

  def empty_data_quality_report
    totals = data_quality_totals([])
    {
      report_date: User.current.today,
      stale_days: @data_quality_stale_days || DATA_QUALITY_DEFAULT_STALE_DAYS,
      totals: totals,
      project_rows: [],
      field_rows: data_quality_field_rows(totals),
      stale_rows: [],
      missing_rows: []
    }
  end

  def bug_analysis_period_dates
    start_date = parse_report_date(params[:bug_start_date]) || (User.current.today - 13)
    end_date = parse_report_date(params[:bug_end_date]) || User.current.today

    start_date, end_date = end_date, start_date if start_date > end_date
    [start_date, end_date]
  end

  def compute_bug_analysis_report(start_date, end_date)
    bugs = Issue.includes(:status, :tracker, { custom_values: :custom_field })
                .where(project_id: project_and_subproject_ids)
                .joins(:tracker)
                .where(trackers: { name: 'Bug' })

    bug_list = bugs.to_a
    return [[], empty_bug_analysis_totals] if bug_list.empty?

    issue_ids = bug_list.map(&:id)
    status_changes = load_attribute_changes(issue_ids, 'status_id')
    closed_status_ids = bug_terminal_status_ids
    period_start = start_date.beginning_of_day
    period_end = end_date.end_of_day
    closed_issue_ids = bug_closed_issue_ids(issue_ids, closed_status_ids, period_start, period_end)

    rows = Hash.new do |hash, reason|
      hash[reason] = {
        reason: reason,
        beginning: 0,
        found: 0,
        closed: 0,
        remaining: 0,
        impact_sum: 0,
        impact_count: 0
      }
    end

    bug_list.each do |issue|
      reason = issue.custom_value_for(BUG_SOURCE_CF_ID)&.value.presence || 'No Bug Source'
      row = rows[reason]
      impact_rating = issue.custom_value_for(BUG_IMPACT_RATING_CF_ID)&.value.to_i

      remaining_at_period_end = issue.created_on <= period_end && !historically_closed?(issue, status_changes[issue.id], period_end, closed_status_ids)

      row[:beginning] += 1 if issue.created_on <= period_start && !historically_closed?(issue, status_changes[issue.id], period_start, closed_status_ids)
      row[:found] += 1 if issue.created_on >= period_start && issue.created_on <= period_end
      row[:closed] += 1 if closed_issue_ids.include?(issue.id)
      row[:remaining] += 1 if remaining_at_period_end
      if remaining_at_period_end && impact_rating.positive?
        row[:impact_sum] += impact_rating
        row[:impact_count] += 1
      end
    end

    totals = {
      beginning: rows.values.sum { |row| row[:beginning] },
      found: rows.values.sum { |row| row[:found] },
      closed: rows.values.sum { |row| row[:closed] },
      remaining: rows.values.sum { |row| row[:remaining] },
      impact_sum: rows.values.sum { |row| row[:impact_sum] },
      impact_count: rows.values.sum { |row| row[:impact_count] }
    }
    totals[:change_percent] = bug_start_end_change(totals[:beginning], totals[:remaining])
    totals[:impact_average] = totals[:impact_count].positive? ? totals[:impact_sum].to_f / totals[:impact_count] : 0.0

    report_rows = rows.values.map do |row|
      row.merge(
        beginning_percent: ratio(row[:beginning], totals[:beginning]),
        found_percent: ratio(row[:found], totals[:found]),
        closed_percent: ratio(row[:closed], totals[:closed]),
        remaining_percent: ratio(row[:remaining], totals[:remaining]),
        change_percent: bug_start_end_change(row[:beginning], row[:remaining]),
        impact_average: row[:impact_count].positive? ? row[:impact_sum].to_f / row[:impact_count] : 0.0
      )
    end

    [sort_bug_analysis_rows(report_rows), totals]
  end

  def sort_bug_analysis_rows(rows)
    sort_key = params[:bug_sort].to_s
    return rows.sort_by { |row| [-row[:remaining], -row[:found], row[:reason].to_s.downcase] } unless BUG_ANALYSIS_SORTABLE_FIELDS.include?(sort_key)

    direction_factor = bug_analysis_sort_direction(sort_key) == 'asc' ? 1 : -1
    rows.sort_by do |row|
      [
        bug_analysis_sort_value(row, sort_key, direction_factor),
        -row[:remaining].to_i,
        row[:reason].to_s.downcase
      ]
    end
  end

  def bug_analysis_sort_value(row, sort_key, direction_factor)
    return row[:reason].to_s.downcase if sort_key == 'reason'

    value = row[sort_key.to_sym]
    value = -Float::INFINITY if value.nil? && direction_factor == -1
    value = Float::INFINITY if value.nil? && direction_factor == 1
    direction_factor * value.to_f
  end

  def bug_analysis_sort_direction(sort_key)
    requested_dir = params[:bug_dir].to_s
    return requested_dir if %w[asc desc].include?(requested_dir)

    sort_key == 'reason' ? 'asc' : 'desc'
  end

  def empty_bug_analysis_totals
    {
      beginning: 0,
      found: 0,
      closed: 0,
      remaining: 0,
      change_percent: nil,
      impact_sum: 0,
      impact_count: 0,
      impact_average: 0.0
    }
  end

  def bug_terminal_status_ids
    IssueStatus.where(is_closed: true)
               .or(IssueStatus.where(name: STATUS_NAMES.fetch(:done) + STATUS_NAMES.fetch(:archived)))
               .pluck(:id)
               .map(&:to_s)
  end

  def bug_closed_issue_ids(issue_ids, closed_status_ids, period_start, period_end)
    require 'set'
    return Set.new if issue_ids.empty? || closed_status_ids.empty?

    Set.new(
      JournalDetail.joins(:journal)
                   .where(
                     journals: {
                       journalized_type: 'Issue',
                       journalized_id: issue_ids,
                       created_on: period_start..period_end
                     },
                     property: 'attr',
                     prop_key: 'status_id',
                     value: closed_status_ids
                   )
                   .pluck('journals.journalized_id')
                   .map(&:to_i)
    )
  end

  def historically_closed?(issue, changes, snapshot_time, closed_status_ids)
    status_id = historical_attribute_value(issue.status_id, changes, snapshot_time)
    closed_status_ids.include?(status_id.to_s)
  end

  def ratio(numerator, denominator)
    return 0.0 if denominator.to_f <= 0

    numerator.to_f / denominator.to_f
  end

  def bug_start_end_change(beginning, remaining)
    return nil if beginning.to_i <= 0

    (remaining.to_f - beginning.to_f) / beginning.to_f
  end

  def flow_period_dates
    start_date = parse_report_date(params[:flow_start_date]) || (User.current.today - 13)
    end_date = parse_report_date(params[:flow_end_date]) || User.current.today

    start_date, end_date = end_date, start_date if start_date > end_date
    [start_date, end_date]
  end

  def parse_report_date(value)
    return if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def flow_snapshot_dates(start_date, end_date)
    return [start_date] if start_date == end_date

    day_count = (end_date - start_date).to_i
    if day_count <= 31
      (start_date..end_date).to_a
    else
      dates = []
      current = start_date
      while current <= end_date
        dates << current
        current += 7
      end
      dates << end_date unless dates.last == end_date
      dates
    end
  end

  def flow_report_issues
    return [] unless @query&.valid?

    issues = @query.issues(
      order: "#{Issue.table_name}.id ASC",
      include: [:status, :tracker, { custom_values: :custom_field }]
    )

    allowed_owner_values = ticket_owner_values_for_role(@selected_owner_role&.id)
    return issues unless allowed_owner_values

    issues.select do |issue|
      owner_value, = ticket_owner_info(issue)
      allowed_owner_values.include?(owner_value.to_s)
    end
  end

  def compute_flow_trends(issues, snapshot_dates)
    return [[], [], { issues: 0, snapshots: snapshot_dates.size, start_total: 0, end_total: 0 }] if issues.empty? || snapshot_dates.empty?

    issue_ids = issues.map(&:id)
    status_changes = load_attribute_changes(issue_ids, 'status_id')
    tracker_changes = load_attribute_changes(issue_ids, 'tracker_id')
    status_names = IssueStatus.pluck(:id, :name).to_h.transform_keys(&:to_s)
    tracker_names = Tracker.pluck(:id, :name).to_h.transform_keys(&:to_s)

    status_counts = Hash.new { |hash, label| hash[label] = Array.new(snapshot_dates.size, 0) }
    tracker_counts = Hash.new { |hash, label| hash[label] = Array.new(snapshot_dates.size, 0) }

    snapshot_dates.each_with_index do |date, index|
      snapshot_time = date.end_of_day

      issues.each do |issue|
        next if issue.created_on && issue.created_on > snapshot_time

        status_id = historical_attribute_value(issue.status_id, status_changes[issue.id], snapshot_time)
        tracker_id = historical_attribute_value(issue.tracker_id, tracker_changes[issue.id], snapshot_time)

        status_counts[status_names[status_id.to_s] || "Status ##{status_id}"][index] += 1
        tracker_counts[tracker_names[tracker_id.to_s] || "Tracker ##{tracker_id}"][index] += 1
      end
    end

    status_rows = build_status_flow_rows(status_counts)
    tracker_rows = build_flow_rows(tracker_counts)
    summary = {
      issues: issues.size,
      snapshots: snapshot_dates.size,
      start_total: status_rows.sum { |row| row[:counts].first.to_i },
      end_total: status_rows.sum { |row| row[:counts].last.to_i }
    }

    [status_rows, tracker_rows, summary]
  end

  def load_attribute_changes(issue_ids, prop_key)
    return {} if issue_ids.empty?

    rows = JournalDetail.joins(:journal)
                        .where(
                          journals: {
                            journalized_type: 'Issue',
                            journalized_id: issue_ids
                          },
                          property: 'attr',
                          prop_key: prop_key
                        )
                        .select(
                          'journals.journalized_id AS issue_id',
                          'journals.created_on AS changed_at',
                          'journal_details.old_value AS old_value',
                          'journal_details.value AS value'
                        )
                        .order('journals.journalized_id ASC, journals.created_on ASC')

    rows.group_by { |row| row.issue_id.to_i }
  end

  def historical_attribute_value(current_value, changes, snapshot_time)
    value = current_value

    Array(changes).reverse_each do |change|
      next unless change.changed_at && change.changed_at > snapshot_time

      value = change.old_value
    end

    value
  end

  def build_flow_rows(counts_by_label)
    counts_by_label.map do |label, counts|
      {
        label: label,
        counts: counts,
        change: counts.last.to_i - counts.first.to_i,
        rate: flow_weekly_rate(counts.last.to_i - counts.first.to_i)
      }
    end.sort_by { |row| [-row[:counts].last.to_i, row[:label].to_s.downcase] }
  end

  def build_status_flow_rows(counts_by_label)
    rows_by_label = counts_by_label.transform_values do |counts|
      {
        counts: counts,
        change: counts.last.to_i - counts.first.to_i,
        rate: flow_weekly_rate(counts.last.to_i - counts.first.to_i)
      }
    end

    ordered_rows = FLOW_STATUS_ORDER.filter_map do |label|
      next unless rows_by_label.key?(label)

      row = rows_by_label.delete(label).merge(label: label)
      row[:separator_before] = FLOW_STATUS_SEPARATOR_BEFORE.include?(label)
      row
    end

    extra_rows = rows_by_label.map do |label, values|
      values.merge(label: label, separator_before: ordered_rows.any?)
    end.sort_by { |row| row[:label].to_s.downcase }

    ordered_rows + extra_rows
  end

  def compute_flow_return_reason_rows(issues)
    return [] if issues.empty?

    issue_ids = issues.map(&:id)
    returned_status_ids = IssueStatus.where(name: STATUS_NAMES.fetch(:returned)).pluck(:id).map(&:to_s)
    return [] if returned_status_ids.empty?

    period_start = @flow_start_date.beginning_of_day
    period_end = @flow_end_date.end_of_day
    reason_by_issue = issues.each_with_object({}) do |issue, hash|
      reason_value = issue.custom_value_for(RETURN_REASON_CF_ID)&.value.presence || 'No Return Reason'
      hash[issue.id] = reason_value
    end

    counts = Hash.new(0)
    JournalDetail.joins(:journal)
                 .where(
                   journals: {
                     journalized_type: 'Issue',
                     journalized_id: issue_ids,
                     created_on: period_start..period_end
                   },
                   property: 'attr',
                   prop_key: 'status_id',
                   value: returned_status_ids
                 )
                 .pluck('journals.journalized_id')
                 .each do |issue_id|
                   counts[reason_by_issue[issue_id.to_i] || 'No Return Reason'] += 1
                 end

    total = counts.values.sum
    return [] if total.zero?

    counts.map do |reason, count|
      {
        reason: reason,
        count: count,
        percent: count.to_f / total.to_f
      }
    end.sort_by { |row| [-row[:count], row[:reason].to_s.downcase] }
  end

  def flow_weekly_rate(change)
    days = (@flow_end_date - @flow_start_date).to_f
    return 0.0 if days <= 0

    change.to_f / (days / 7.0)
  end

  def build_report_sections(issues_data)
    grouped = issues_data.group_by { |item| item[:family_key] }

    TRACKER_FAMILY_ORDER.filter_map do |family_key|
      items = grouped[family_key] || []
      next if items.empty?

      {
        family_key: family_key,
        label: TRACKER_FAMILY_DEFINITIONS.fetch(family_key).fetch(:label),
        items: sort_report_issues_data(items, family_key)
      }
    end
  end

  def sort_report_issues_data(issues_data, family_key)
    sort_key = params[:report_sort].to_s
    return issues_data unless report_sortable_fields_for_family(family_key).include?(sort_key)
    return issues_data unless report_sort_applies_to_family?(family_key)

    direction_factor = params[:report_dir].to_s == 'asc' ? 1 : -1

    issues_data.sort_by do |item|
      [
        direction_factor * report_sort_numeric_value(item, sort_key, family_key),
        report_sort_tie_breaker(item, sort_key, family_key),
        item[:issue].id
      ]
    end
  end

  def report_sort_applies_to_family?(family_key)
    requested_family = params[:report_family].to_s
    requested_family.blank? || requested_family == family_key.to_s
  end

  def report_sortable_fields_for_family(family_key)
    extra_fields = %w[TOTAL ON_HOLD]
    extra_fields << 'PENDING' unless family_key.to_sym == :customer_support
    (FAMILY_DURATION_KEYS.fetch(family_key).map(&:to_s) + extra_fields + %w[CALENDAR_TOTAL peak]).concat(FAMILY_COUNTER_KEYS.fetch(family_key).map(&:to_s))
  end

  def report_sort_numeric_value(item, sort_key, family_key)
    durations = item[:durations]

    case sort_key
    when 'peak'
      report_peak_duration_value(durations, family_key)
    when *ALL_COUNTER_KEYS.map(&:to_s)
      durations[sort_key.to_sym].to_i
    else
      durations[sort_key.to_sym].to_f
    end
  end

  def report_sort_tie_breaker(item, sort_key, family_key)
    return report_peak_duration_index(item[:durations], family_key) if sort_key == 'peak'

    0
  end

  def report_peak_duration_value(durations, family_key)
    FAMILY_DURATION_KEYS.fetch(family_key).map { |key| durations[key].to_f }.max || 0.0
  end

  def report_peak_duration_index(durations, family_key)
    FAMILY_DURATION_KEYS.fetch(family_key)
                        .each_with_index
                        .max_by { |(key, index)| [durations[key].to_f, -index] }
                        &.last || 0
  end

  def compute_owner_returns_summary(issues_data, role_id: nil)
    allowed_owner_values = ticket_owner_values_for_role(role_id)

    rows = Hash.new do |hash, owner_key|
      owner_value, owner_name = owner_key
      hash[owner_key] = {
        owner: owner_name,
        owner_value: owner_value,
        total_tickets: 0,
        done_tickets: 0,
        done_cycle_count: 0,
        done_cycle_hours: 0.0,
        priority_done_cycle_count: 0,
        priority_done_cycle_hours: 0.0,
        avg_done_cycle_time: 0.0,
        avg_priority_done_cycle_time: 0.0,
        returned_tickets: 0,
        c1: 0,
        c2: 0,
        c3: 0,
        c4: 0,
        total_returns: 0
      }
    end

    issues_data.each do |item|
      owner_value, owner_name = ticket_owner_info(item[:issue])
      next if allowed_owner_values && !allowed_owner_values.include?(owner_value.to_s)

      row = rows[[owner_value, owner_name]]
      row[:total_tickets] += 1

      cycle_hours = done_cycle_time_hours(item)
      if status_role(item[:issue].status&.name) == :done
        row[:done_tickets] += 1
        if cycle_hours
          row[:done_cycle_count] += 1
          row[:done_cycle_hours] += cycle_hours

          if priority_performance_ticket?(item[:issue])
            row[:priority_done_cycle_count] += 1
            row[:priority_done_cycle_hours] += cycle_hours
          end
        end
      end

      durations = item[:durations]
      total_returns = durations[:C1].to_i + durations[:C2].to_i + durations[:C3].to_i + durations[:C4].to_i
      next if total_returns.zero?

      row[:returned_tickets] += 1
      row[:c1] += durations[:C1].to_i
      row[:c2] += durations[:C2].to_i
      row[:c3] += durations[:C3].to_i
      row[:c4] += durations[:C4].to_i
      row[:total_returns] += total_returns
    end

    owner_rows = rows.values
    owner_rows.each do |row|
      row[:avg_done_cycle_time] = row[:done_cycle_count].positive? ? row[:done_cycle_hours] / row[:done_cycle_count] : 0.0
      row[:avg_priority_done_cycle_time] = row[:priority_done_cycle_count].positive? ? row[:priority_done_cycle_hours] / row[:priority_done_cycle_count] : 0.0
    end

    sort_owner_return_rows(owner_rows)
  end

  def done_cycle_time_hours(item)
    issue = item[:issue]
    return unless status_role(issue.status&.name) == :done

    cycle_time_hours_from_periods(item)
  end

  def completed_cycle_time_hours(item)
    issue = item[:issue]
    return unless %i[done archived].include?(status_role(issue.status&.name))

    cycle_time_hours_from_periods(item)
  end

  def cycle_time_hours_from_periods(item)
    periods = item[:durations][:periods] || []
    end_time = terminal_time_for_periods(periods)
    start_time = periods.find { |period| status_role(period[:status]) == :in_progress }&.dig(:enter)
    return unless start_time && end_time && start_time < end_time

    cycle_periods = periods.filter_map do |period|
      next if period[:enter].blank? || period[:exit].blank?
      next if period[:exit] <= start_time || period[:enter] >= end_time

      clipped = period.dup
      clipped[:enter] = [period[:enter], start_time].max
      clipped[:exit] = [period[:exit], end_time].min
      next if clipped[:exit] <= clipped[:enter]

      clipped
    end

    active_periods = remove_pause_time_from_periods(
      cycle_periods,
      pause_periods_for_summary(cycle_periods, item[:family_key])
    )
    active_periods.sum { |period| period_hours(period) }
  end

  def priority_performance_ticket?(issue)
    priority_name = issue.priority&.name.to_s.downcase
    priority_name.include?('urgent') || priority_name.include?('immediate')
  end

  def sort_owner_return_rows(rows)
    sort_key = params[:owner_sort].to_s
    return rows.sort_by { |row| [-row[:total_returns], -row[:total_tickets], row[:owner].downcase] } unless OWNER_RETURN_SORTABLE_FIELDS.include?(sort_key)

    total_ticket_count = rows.sum { |row| row[:total_tickets].to_i }
    direction_factor = owner_return_sort_direction(sort_key) == 'asc' ? 1 : -1

    rows.sort_by do |row|
      [
        owner_return_sort_primary(row, sort_key, total_ticket_count, direction_factor),
        owner_return_sort_secondary(row, sort_key, direction_factor),
        row[:owner].to_s.downcase
      ]
    end
  end

  def owner_return_sort_primary(row, sort_key, total_ticket_count, direction_factor)
    case sort_key
    when 'owner'
      row[:owner].to_s.downcase
    when 'ticket_share'
      direction_factor * owner_return_ticket_share(row, total_ticket_count)
    when 'return_rate'
      direction_factor * owner_return_rate(row)
    else
      direction_factor * row[sort_key.to_sym].to_f
    end
  end

  def owner_return_sort_secondary(row, sort_key, direction_factor)
    return row[:total_returns].to_i * direction_factor if %w[ticket_share return_rate].include?(sort_key)
    return 0 if sort_key == 'owner'

    row[:total_tickets].to_i * direction_factor
  end

  def owner_return_ticket_share(row, total_ticket_count)
    return 0.0 if total_ticket_count.to_f <= 0

    row[:total_tickets].to_f / total_ticket_count.to_f
  end

  def owner_return_rate(row)
    return 0.0 if row[:total_tickets].to_f <= 0

    row[:returned_tickets].to_f / row[:total_tickets].to_f
  end

  def owner_return_sort_direction(sort_key)
    requested_dir = params[:owner_dir].to_s
    return requested_dir if %w[asc desc].include?(requested_dir)

    sort_key == 'owner' ? 'asc' : 'desc'
  end

  def ticket_owner_values_for_role(role_id)
    return nil if role_id.blank?

    @ticket_owner_values_for_role ||= {}
    @ticket_owner_values_for_role[role_id] ||= Member.joins(:member_roles)
                                                    .where(project_id: project_and_subproject_ids, member_roles: { role_id: role_id })
                                                    .distinct
                                                    .pluck(:user_id)
                                                    .compact
                                                    .map(&:to_s)
  end

  def ticket_owner_info(issue)
    custom_value = issue.custom_value_for(TICKET_OWNER_CF_ID)
    raw_value = custom_value&.value.presence
    return [nil, 'Unassigned'] if raw_value.blank?

    display_value =
      if custom_value.custom_field.field_format == 'user'
        ticket_owner_user_name(raw_value)
      else
        raw_value
      end

    [raw_value, display_value]
  end

  def ticket_owner_user_name(raw_value)
    @ticket_owner_name_cache ||= {}
    @ticket_owner_name_cache[raw_value] ||= Principal.find_by(id: raw_value)&.name || raw_value
  end

  # ---------------------------------------------------------------
  # COMPUTE DURATIONS FOR A SINGLE ISSUE
  # ---------------------------------------------------------------
  def compute_issue_durations(issue)
    transitions = load_transitions(issue)[issue.id] || []
    calculate_durations_for_family(tracker_family_for_issue(issue), transitions)
  end

  # ---------------------------------------------------------------
  # CORE DURATION ALGORITHM
  # ---------------------------------------------------------------
  def calculate_durations_for_family(family_key, transitions)
    periods = build_periods(transitions)
    return empty_durations(periods: periods) if periods.empty?

    stage_periods = build_stage_periods(periods, family_key)

    case family_key
    when :customer_support
      calculate_customer_support_durations(periods, stage_periods)
    when :task
      calculate_task_durations(periods, stage_periods)
    when :container
      calculate_container_durations(periods, stage_periods)
    else
      calculate_internal_durations(periods, stage_periods)
    end
  end

  def calculate_internal_durations(periods, stage_periods)
    result = empty_durations(periods: periods)
    visits = visits_by_role(stage_periods)
    result[:ON_HOLD] = periods.select { |period| status_role(period[:status]) == :on_hold }.sum { |period| period_hours(period) }
    result[:PENDING] = periods.select { |period| status_role(period[:status]) == :pending }.sum { |period| period_hours(period) }

    stage_periods.each_with_index do |period, index|
      next_role = period_next_role(stage_periods, index)
      duration = period_hours(period)

      case status_role(period[:status])
      when :new
        result[:D0] += duration if next_role == :todo
        result[:D0aug] += duration if next_role == :archived
        result[:D7] += duration if next_role == :feedback
      when :feedback
        case next_role
        when :archived
          result[:D9] += duration
        when :new
          result[:D8] += duration
        when :returned
          result[:D3aug] += duration
        else
          if result[:D3].zero?
            result[:D3] += duration
          else
            result[:D3aug] += duration
          end
        end
      when :review
        result[:D4] += duration if next_role == :ready_merge
        result[:D4aug] += duration if next_role == :returned
      when :ready_merge
        result[:D5] += duration if next_role == :final_check
        result[:D5aug] += duration if next_role == :returned
      when :final_check
        result[:D6] += duration if next_role == :done
        result[:D6aug] += duration if next_role == :returned
      end
    end

    todo_visits = visits[:todo] || []
    returned_visits = visits[:returned] || []
    in_progress_visits = visits[:in_progress] || []

    result[:D1] = period_hours(todo_visits.first)
    result[:D1aug] = Array(todo_visits[1..]).sum { |period| period_hours(period) } + returned_visits.sum { |period| period_hours(period) }
    result[:D2] = period_hours(in_progress_visits.first)
    result[:D2aug] = Array(in_progress_visits[1..]).sum { |period| period_hours(period) }

    stage_periods.each_cons(2) do |current_period, next_period|
      next unless status_role(next_period[:status]) == :returned

      case status_role(current_period[:status])
      when :feedback
        result[:C1] += 1
      when :review
        result[:C2] += 1
      when :ready_merge
        result[:C3] += 1
      when :final_check
        result[:C4] += 1
      end
    end

    total_keys = FAMILY_DURATION_KEYS[:internal] - %i[D0 D0aug]
    result[:TOTAL] = total_keys.sum { |key| result[key].to_f }
    result[:CALENDAR_TOTAL] = result[:TOTAL].to_f + result[:D0].to_f + result[:D0aug].to_f + result[:ON_HOLD].to_f + result[:PENDING].to_f
    result
  end

  def calculate_customer_support_durations(periods, stage_periods)
    result = empty_durations(periods: periods)
    result[:ON_HOLD] = periods.select { |period| status_role(period[:status]) == :on_hold }.sum { |period| period_hours(period) }

    stage_periods.each_with_index do |period, index|
      next_role = period_next_role(stage_periods, index)
      duration = period_hours(period)

      case status_role(period[:status])
      when :new
        result[:DC0] += duration if next_role == :review
        result[:DC1] += duration if next_role == :archived
      when :review
        result[:DC1] += duration if next_role == :archived
        result[:DC2] += duration if next_role == :feedback
        result[:DC3] += duration if next_role == :in_progress
        result[:DC4] += duration if next_role == :done
      when :feedback
        result[:DC5] += duration if next_role == :in_progress
        result[:DC6] += duration if next_role == :done
      when :in_progress
        result[:DC7] += duration if next_role == :done
      end
    end

    total_keys = FAMILY_DURATION_KEYS[:customer_support] - %i[DC0 DC1]
    result[:TOTAL] = total_keys.sum { |key| result[key].to_f }
    result[:CALENDAR_TOTAL] = result[:TOTAL].to_f + result[:DC0].to_f + result[:DC1].to_f + result[:ON_HOLD].to_f
    result
  end

  def calculate_task_durations(periods, stage_periods)
    result = empty_durations(periods: periods)
    visits = visits_by_role(stage_periods)
    result[:ON_HOLD] = periods.select { |period| status_role(period[:status]) == :on_hold }.sum { |period| period_hours(period) }
    result[:PENDING] = periods.select { |period| status_role(period[:status]) == :pending }.sum { |period| period_hours(period) }

    stage_periods.each_with_index do |period, index|
      next_role = period_next_role(stage_periods, index)
      duration = period_hours(period)

      case status_role(period[:status])
      when :new
        result[:DT0] += duration if next_role == :todo
      when :feedback
        result[:DT3] += duration if next_role == :final_check
        result[:DT3aug] += duration if next_role == :returned
      when :final_check
        result[:DT4] += duration if next_role == :done
        result[:DT4aug] += duration if next_role == :returned
      end
    end

    todo_visits = visits[:todo] || []
    returned_visits = visits[:returned] || []
    in_progress_visits = visits[:in_progress] || []

    result[:DT1] = period_hours(todo_visits.first)
    result[:DT1aug] = Array(todo_visits[1..]).sum { |period| period_hours(period) } + returned_visits.sum { |period| period_hours(period) }
    result[:DT2] = period_hours(in_progress_visits.first)
    result[:DT2aug] = Array(in_progress_visits[1..]).sum { |period| period_hours(period) }

    stage_periods.each_cons(2) do |current_period, next_period|
      next unless status_role(next_period[:status]) == :returned

      case status_role(current_period[:status])
      when :feedback
        result[:C1] += 1
      when :final_check
        result[:C4] += 1
      end
    end

    total_keys = FAMILY_DURATION_KEYS[:task] - [:DT0]
    result[:TOTAL] = total_keys.sum { |key| result[key].to_f }
    result[:CALENDAR_TOTAL] = result[:TOTAL].to_f + result[:DT0].to_f + result[:ON_HOLD].to_f + result[:PENDING].to_f
    result
  end

  def calculate_container_durations(periods, stage_periods)
    result = empty_durations(periods: periods)
    result[:ON_HOLD] = periods.select { |period| status_role(period[:status]) == :on_hold }.sum { |period| period_hours(period) }
    result[:PENDING] = periods.select { |period| status_role(period[:status]) == :pending }.sum { |period| period_hours(period) }

    stage_periods.each_with_index do |period, index|
      next_role = period_next_role(stage_periods, index)
      duration = period_hours(period)

      case status_role(period[:status])
      when :new
        result[:DP0] += duration if next_role == :todo
      when :todo
        result[:DP1] += duration if next_role == :in_progress
      when :in_progress
        result[:DP2] += duration if next_role == :final_check
      when :final_check
        result[:DP3] += duration if next_role == :done
      end
    end

    total_keys = FAMILY_DURATION_KEYS[:container] - [:DP0]
    result[:TOTAL] = total_keys.sum { |key| result[key].to_f }
    result[:CALENDAR_TOTAL] = result[:TOTAL].to_f + result[:DP0].to_f + result[:ON_HOLD].to_f + result[:PENDING].to_f
    result
  end

  def build_periods(transitions)
    sorted = transitions.sort_by { |t| t[:changed_at] }
    periods = []

    sorted.each_with_index do |transition, index|
      status = transition[:to_status]
      next if status.nil?

      enter_time = transition[:changed_at]
      next_transition = sorted[index + 1]
      exit_time = next_transition ? next_transition[:changed_at] : Time.current

      periods << {
        status: status,
        enter: enter_time,
        exit: exit_time
      }
    end

    merged = []
    periods.each do |period|
      last = merged.last
      if last && last[:status] == period[:status]
        last[:exit] = period[:exit]
      else
        merged << period.dup
      end
    end

    merged
  end

  def visits_by_role(periods)
    visits = Hash.new { |hash, role| hash[role] = [] }

    periods.each do |period|
      visits[status_role(period[:status])] << period
    end

    visits
  end

  def build_stage_periods(periods, family_key)
    pause_roles = pause_roles_for_family(family_key)
    stage_periods = []

    periods.each do |period|
      role = status_role(period[:status])
      next if pause_roles.include?(role)

      duration = period_hours(period)
      next if duration <= 0

      if stage_periods.last && status_role(stage_periods.last[:status]) == role
        stage_periods.last[:hours] += duration
      else
        stage_periods << {
          status: period[:status],
          hours: duration
        }
      end
    end

    stage_periods
  end

  def pause_roles_for_family(family_key)
    roles = [:on_hold]
    roles << :pending unless family_key.to_sym == :customer_support
    roles
  end

  def period_next_role(periods, index)
    next_period = periods[index + 1]
    status_role(next_period&.dig(:status))
  end

  def period_hours(period)
    return period[:hours].to_f if period && period.key?(:hours)
    return 0.0 unless period && period[:enter] && period[:exit]

    [((period[:exit] - period[:enter]) / 3600.0), 0].max.round(2)
  end

  def load_assignment_periods(issue)
    journals = issue.journals.includes(:user, :details).order(:created_on)
    assignment_periods = []
    current_assignee = nil
    start_time = issue.created_on

    journals.each do |journal|
      journal.details.each do |detail|
        next unless detail.property == 'attr' && detail.prop_key == 'assigned_to_id'

        old_assignee = user_name_for_id(detail.old_value)
        new_assignee = user_name_for_id(detail.value)
        current_assignee ||= old_assignee || 'Unassigned'

        assignment_periods << {
          assignee: current_assignee,
          enter: start_time,
          exit: journal.created_on,
          changed_by: journal.user&.name
        }

        current_assignee = new_assignee || 'Unassigned'
        start_time = journal.created_on
      end
    end

    assignment_periods << {
      assignee: current_assignee || issue.assigned_to&.name || 'Unassigned',
      enter: start_time,
      exit: Time.current,
      changed_by: 'Current'
    }

    assignment_periods
  end

  def user_name_for_id(user_id)
    return nil if user_id.blank?

    User.find_by(id: user_id)&.name
  end

  def summarize_named_periods(periods, label_key)
    totals = Hash.new(0.0)
    counts = Hash.new(0)

    periods.each do |period|
      label = period[label_key].presence || 'Unknown'
      totals[label] += period_hours(period)
      counts[label] += 1
    end

    grand_total = totals.values.sum
    totals.map do |label, hours|
      {
        label: label,
        count: counts[label],
        hours: hours,
        percentage: grand_total.positive? ? ((hours / grand_total) * 100).round(1) : 0.0
      }
    end.sort_by { |row| [-row[:hours], row[:label].to_s.downcase] }
  end

  def terminal_time_for_periods(periods)
    terminal_period = periods.last
    return unless terminal_period && %i[done archived].include?(status_role(terminal_period[:status]))

    terminal_period[:enter]
  end

  def clipped_periods(periods, cutoff_time, exclude_terminal: false)
    return periods if cutoff_time.blank?

    periods.filter_map do |period|
      next if period[:enter].blank? || period[:enter] >= cutoff_time
      next if exclude_terminal && %i[done archived].include?(status_role(period[:status]))

      clipped = period.dup
      clipped[:exit] = [period[:exit], cutoff_time].compact.min
      next if clipped[:exit].blank? || clipped[:exit] <= clipped[:enter]

      clipped
    end
  end

  def pause_periods_for_summary(periods, family_key)
    pause_roles = pause_roles_for_family(family_key)

    periods.select { |period| pause_roles.include?(status_role(period[:status])) }
  end

  def remove_pause_time_from_periods(periods, pause_periods)
    return periods if pause_periods.blank?

    periods.filter_map do |period|
      active_hours = period_hours(period) - overlapping_hours(period, pause_periods)
      next if active_hours <= 0

      period.merge(hours: active_hours.round(2))
    end
  end

  def overlapping_hours(period, other_periods)
    other_periods.sum do |other_period|
      overlap_start = [period[:enter], other_period[:enter]].compact.max
      overlap_end = [period[:exit], other_period[:exit]].compact.min
      next 0.0 if overlap_start.blank? || overlap_end.blank? || overlap_end <= overlap_start

      ((overlap_end - overlap_start) / 3600.0).round(2)
    end
  end

  def sum_role_hours(visits, role)
    (visits[role] || []).sum { |period| period_hours(period) }
  end

  def empty_durations(periods: [])
    ALL_DURATION_KEYS.each_with_object({ periods: periods }) do |key, hash|
      hash[key] = 0.0
    end.merge(C1: 0, C2: 0, C3: 0, C4: 0, periods: periods)
  end

  # ---------------------------------------------------------------
  # CSV GENERATION
  # ---------------------------------------------------------------
  def generate_csv(report_sections)
    require 'csv'

    CSV.generate(headers: false, encoding: 'UTF-8') do |csv|
      report_sections.each_with_index do |section, index|
        csv << [] unless index.zero?
        csv << [section[:label]]

        extra_fields = [:TOTAL, :ON_HOLD]
        extra_fields << :PENDING unless section[:family_key].to_sym == :customer_support
        value_fields = FAMILY_DURATION_KEYS.fetch(section[:family_key]) + extra_fields + [:CALENDAR_TOTAL] + FAMILY_COUNTER_KEYS.fetch(section[:family_key])
        csv << ['issue_id', 'subject', 'status', 'assignee', 'tracker', *value_fields.map { |field| csv_header_label_for(field) }, 'Peak']

        section[:items].each do |item|
          issue = item[:issue]
          durations = item[:durations]

          csv << [
            issue.id,
            issue.subject,
            issue.status.name,
            issue.assigned_to&.name,
            issue.tracker&.name,
            *value_fields.map { |field| durations[field] || 0 },
            view_context.peak_duration_label(durations, section[:family_key])
          ]
        end
      end
    end
  end

  def csv_header_label_for(field)
    return 'On-Hold' if field == :ON_HOLD
    return 'Pending' if field == :PENDING
    return 'Cycle Total' if field == :TOTAL
    return 'Calendar Total' if field == :CALENDAR_TOTAL
    return field.to_s.sub(/\AC/, 'R') if ALL_COUNTER_KEYS.include?(field)

    field.to_s
  end
end
