class TicketJourneyController < ApplicationController
  TICKET_OWNER_CF_ID = 57
  REPORT_SORTABLE_FIELDS = %w[D1 D2 D2aug D3 D3aug D4 D4aug D5 D5aug D6 D6aug D7 D7aug D8 D9 D10 ON_HOLD TOTAL peak_d C1 C2 C3 C4].freeze
  OWNER_RETURN_SORTABLE_FIELDS = %w[owner total_tickets ticket_share returned_tickets return_rate c1 c2 c3 c4 total_returns].freeze

  before_action :find_project
  before_action :authorize
  before_action :build_query, only: [:index, :owner_returns, :export]
  before_action :prepare_owner_role_filter, only: [:owner_returns]

  helper :queries

  # ---------------------------------------------------------------
  # INDEX — list all issues with computed durations
  # ---------------------------------------------------------------
  def index
    @issues_data = compute_all_durations
  end

  # ---------------------------------------------------------------
  # OWNER RETURNS — summary of returned tickets by ticket owner
  # ---------------------------------------------------------------
  def owner_returns
    @issues_data = compute_all_durations
    @owner_return_rows = compute_owner_returns_summary(@issues_data, role_id: @selected_owner_role&.id)
  end

  # ---------------------------------------------------------------
  # SHOW — single issue detail
  # ---------------------------------------------------------------
  def show
    @issue = Issue.includes(:status, :author, :assigned_to, :tracker).find(params[:id])
    return render_403 unless @issue.project == @project

    @duration_data = compute_issue_durations(@issue)
    @transitions   = load_transitions(@issue)[@issue.id] || []
  end
  # ---------------------------------------------------------------
  # EXPORT — CSV download
  # ---------------------------------------------------------------
  def export
    @issues_data = compute_all_durations
    respond_to do |format|
      format.csv do
        send_data generate_csv(@issues_data),
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
      @query.column_names = [:id, :subject, :status]
    end
  end

  def prepare_owner_role_filter
    @owner_roles = Role.joins(member_roles: :member)
                       .where(members: { project_id: @project.id })
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
    in_progress:  ['In Progress'],
    feedback:     ['Feedback'],
    review:       ['Review'],
    ready_merge:  ['Ready to Merge'],
    final_check:  ['Final Check'],
    on_hold:      ['On-Hold'],
    archived:     ['Archived'],
    done:         ['Done / Closed'],
  }.freeze

  def status_role(status_name)
    return :unknown if status_name.nil?
    n = status_name.downcase.strip
    STATUS_NAMES.each do |role, names|
      return role if names.any? { |sn| sn.downcase == n }
    end
    :unknown
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
      include: [:status, :author, :assigned_to, :tracker, { custom_values: :custom_field }]
    )
    all_transitions = load_transitions(issues)

    issues_data = issues.map do |issue|
      transitions = all_transitions[issue.id] || []
      durations = calculate_durations_from_transitions(transitions)

      {
        issue: issue,
        durations: durations
      }
    end

    sort_report_issues_data(issues_data)
  end

  def sort_report_issues_data(issues_data)
    sort_key = params[:report_sort].to_s
    return issues_data unless REPORT_SORTABLE_FIELDS.include?(sort_key)

    direction_factor = params[:report_dir].to_s == 'asc' ? 1 : -1

    issues_data.sort_by do |item|
      [
        direction_factor * report_sort_numeric_value(item, sort_key),
        report_sort_tie_breaker(item, sort_key),
        item[:issue].id
      ]
    end
  end

  def report_sort_numeric_value(item, sort_key)
    durations = item[:durations]

    case sort_key
    when 'peak_d'
      report_peak_duration_value(durations)
    when 'C1', 'C2', 'C3', 'C4'
      durations[sort_key.to_sym].to_i
    else
      durations[sort_key.to_sym].to_f
    end
  end

  def report_sort_tie_breaker(item, sort_key)
    return report_peak_duration_index(item[:durations]) if sort_key == 'peak_d'

    0
  end

  def report_peak_duration_value(durations)
    d_duration_keys.map { |key| durations[key].to_f }.max || 0.0
  end

  def report_peak_duration_index(durations)
    d_duration_keys.each_with_index.max_by { |key, index| [durations[key].to_f, -index] }&.last || 0
  end

  def d_duration_keys
    @d_duration_keys ||= %i[D1 D2 D2aug D3 D3aug D4 D4aug D5 D5aug D6 D6aug D7aug D7 D8 D9 D10]
  end

  def compute_owner_returns_summary(issues_data, role_id: nil)
    allowed_owner_values = ticket_owner_values_for_role(role_id)

    rows = Hash.new do |hash, owner_key|
      owner_value, owner_name = owner_key
      hash[owner_key] = {
        owner: owner_name,
        owner_value: owner_value,
        total_tickets: 0,
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

    sort_owner_return_rows(rows.values)
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
                                                    .where(project_id: @project.id, member_roles: { role_id: role_id })
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
    calculate_durations_from_transitions(transitions)
  end

  # ---------------------------------------------------------------
  # CORE DURATION ALGORITHM
  # ---------------------------------------------------------------
  def calculate_durations_from_transitions(transitions)
    return empty_durations if transitions.empty?

    periods = build_periods(transitions)

    visit_index = Hash.new(0)
    visits      = Hash.new { |h, k| h[k] = [] }

    periods.each do |p|
      role = status_role(p[:status])
      visit_index[role] += 1
      p[:visit] = visit_index[role]
      visits[role] << p
    end

    hours = ->(a, b) { a && b ? [(b - a) / 3600.0, 0].max.round(2) : 0.0 }
    v = ->(role) { visits[role] || [] }
    on_hold = v.call(:on_hold).sum { |p| hours.call(p[:enter], p[:exit]) }

    d1 = 0.0
    d8 = 0.0

    periods.each_with_index do |period, index|
      next unless status_role(period[:status]) == :new

      next_period = periods[index + 1]
      new_duration = hours.call(period[:enter], period[:exit])

      case status_role(next_period&.dig(:status))
      when :todo
        d1 += new_duration
      when :feedback
        d8 += new_duration
      end
    end

    todo_visits = v.call(:todo)
    returned_visits = v.call(:returned)

    d2 = todo_visits[0] ? hours.call(todo_visits[0][:enter], todo_visits[0][:exit]) : 0.0

    d2aug =
      (todo_visits[1..] || []).sum { |p| hours.call(p[:enter], p[:exit]) } +
      returned_visits.sum { |p| hours.call(p[:enter], p[:exit]) }

    ip_visits = v.call(:in_progress)
    d3    = ip_visits[0] ? hours.call(ip_visits[0][:enter], ip_visits[0][:exit]) : 0.0
    d3aug = (ip_visits[1..] || []).sum { |p| hours.call(p[:enter], p[:exit]) }

    d4 = 0.0
    d4aug = 0.0
    d9 = 0.0
    d10 = 0.0
    non_validation_feedback_visits = 0

    periods.each_with_index do |period, index|
      next unless status_role(period[:status]) == :feedback

      next_period = periods[index + 1]
      feedback_duration = hours.call(period[:enter], period[:exit])
      next_role = status_role(next_period&.dig(:status))

      case next_role
      when :archived
        d10 += feedback_duration
      when :new
        d9 += feedback_duration
      else
        non_validation_feedback_visits += 1
        if non_validation_feedback_visits == 1
          d4 += feedback_duration
        else
          d4aug += feedback_duration
        end
      end
    end

    d5 = 0.0
    d5aug = 0.0

    periods.each_with_index do |period, index|
      next unless status_role(period[:status]) == :review

      next_period = periods[index + 1]
      review_duration = hours.call(period[:enter], period[:exit])

      case status_role(next_period&.dig(:status))
      when :ready_merge
        d5 += review_duration
      when :returned
        d5aug += review_duration
      end
    end

    d6 = 0.0
    d6aug = 0.0

    periods.each_with_index do |period, index|
      next unless status_role(period[:status]) == :ready_merge

      next_period = periods[index + 1]
      merge_duration = hours.call(period[:enter], period[:exit])

      case status_role(next_period&.dig(:status))
      when :final_check
        d6 += merge_duration
      when :returned
        d6aug += merge_duration
      end
    end

    d7 = 0.0
    d7aug = 0.0

    periods.each_with_index do |period, index|
      next unless status_role(period[:status]) == :final_check

      next_period = periods[index + 1]
      final_check_duration = hours.call(period[:enter], period[:exit])

      case status_role(next_period&.dig(:status))
      when :done
        d7 += final_check_duration
      when :returned
        d7aug += final_check_duration
      end
    end

    c1 = c2 = c3 = c4 = 0

    periods.each_cons(2) do |a, b|
      next unless status_role(b[:status]) == :returned

      case status_role(a[:status])
      when :feedback
        c1 += 1
      when :review
        c2 += 1
      when :ready_merge
        c3 += 1
      when :final_check
        c4 += 1
      end
    end

    total = d1 + d2 + d2aug + d3 + d3aug + d4 + d4aug + d5 + d5aug + d6 + d6aug + d7aug + d7 + d8 + d9 + d10

    {
      D1: d1, D2: d2, D2aug: d2aug,
      D3: d3, D3aug: d3aug,
      D4: d4, D4aug: d4aug,
      D5: d5, D5aug: d5aug,
      D6: d6, D6aug: d6aug,
      D7aug: d7aug, D7: d7, D8: d8, D9: d9, D10: d10, ON_HOLD: on_hold,
      TOTAL: total,
      C1: c1, C2: c2, C3: c3, C4: c4,
      periods: periods
    }
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

  def empty_durations
    {
      D1: 0.0, D2: 0.0, D2aug: 0.0,
      D3: 0.0, D3aug: 0.0,
      D4: 0.0, D4aug: 0.0,
      D5: 0.0, D5aug: 0.0,
      D6: 0.0, D6aug: 0.0,
      D7aug: 0.0, D7: 0.0, D8: 0.0, D9: 0.0, D10: 0.0, ON_HOLD: 0.0,
      TOTAL: 0.0,
      C1: 0, C2: 0, C3: 0, C4: 0,
      periods: []
    }
  end

  # ---------------------------------------------------------------
  # CSV GENERATION
  # ---------------------------------------------------------------
  def generate_csv(issues_data)
    require 'csv'
    value_fields = %w[D1 D2 D2aug D3 D3aug D4 D4aug D5 D5aug D6 D6aug D7aug D7 D8 D9 D10 ON_HOLD TOTAL C1 C2 C3 C4]
    header_fields = value_fields.map do |field|
      case field
      when 'ON_HOLD'
        'On-Hold'
      else
        field.sub(/\AC/, 'R')
      end
    end
    CSV.generate(headers: true, encoding: 'UTF-8') do |csv|
      csv << ['issue_id', 'subject', 'status', 'assignee', 'tracker', *header_fields, 'peak_d']
      issues_data.each do |item|
        iss = item[:issue]
        dur = item[:durations]
        csv << [
          iss.id, iss.subject, iss.status.name,
          iss.assigned_to&.name, iss.tracker.name,
          *value_fields.map { |f| dur[f.to_sym] || 0 },
          view_context.peak_duration_label(dur)
        ]
      end
    end
  end
end
