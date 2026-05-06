class TicketJourneyController < ApplicationController
  TICKET_OWNER_CF_ID = 57
  RETURN_REASON_CF_ID = 66
  OWNER_RETURN_SORTABLE_FIELDS = %w[owner total_tickets ticket_share done_tickets avg_done_cycle_time avg_priority_done_cycle_time returned_tickets return_rate c1 c2 c3 c4 total_returns].freeze
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
  before_action :build_query, only: [:index, :owner_returns, :flow_report, :project_health, :export]
  before_action :prepare_owner_role_filter, only: [:owner_returns, :flow_report]

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
  # OWNER RETURNS — summary of returned tickets by ticket owner
  # ---------------------------------------------------------------
  def owner_returns
    @issues_data = compute_all_durations
    @owner_return_rows = compute_owner_returns_summary(@issues_data, role_id: @selected_owner_role&.id)
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
  # FIND PROJECT (standard Redmine pattern)
  # ---------------------------------------------------------------
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def build_query
    base_query =
      if params[:query_id].present?
        IssueQuery.visible.where(project_id: [nil, @project.id]).find_by(id: params[:query_id])
      else
        IssueQuery.default(project: @project, user: User.current)
      end

    @query = (base_query || IssueQuery.new(name: '_'))
    @query.project = @project
    @query.build_from_params(params, project: @project)

    unless params[:query_id].present? || params[:c].present? || params.dig(:query, :column_names).present?
      @query.column_names = [:id, :subject, :status, "cf_#{TICKET_OWNER_CF_ID}"]
    end
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

  def flow_period_dates
    start_date = parse_flow_date(params[:flow_start_date]) || (User.current.today - 13)
    end_date = parse_flow_date(params[:flow_end_date]) || User.current.today

    start_date, end_date = end_date, start_date if start_date > end_date
    [start_date, end_date]
  end

  def parse_flow_date(value)
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
