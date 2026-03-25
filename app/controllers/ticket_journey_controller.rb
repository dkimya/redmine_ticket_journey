class TicketJourneyController < ApplicationController
  before_action :find_project
  before_action :authorize

  # ---------------------------------------------------------------
  # INDEX — list all issues with computed durations
  # ---------------------------------------------------------------
  def index
    @date_from = params[:date_from].present? ? (Date.parse(params[:date_from]) rescue nil) : nil
    @date_to   = params[:date_to].present?   ? (Date.parse(params[:date_to])   rescue nil) : nil
    @tracker_id = params[:tracker_id].presence
    @assignee_id = params[:assignee_id].presence

    @trackers  = @project.trackers.sorted
    @members   = @project.members.includes(:user).map(&:user).sort_by(&:name)

    @issues_data = compute_all_durations
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

  # ---------------------------------------------------------------
  # STATUS NAME CONFIGURATION
  # ---------------------------------------------------------------
  STATUS_NAMES = {
    new:          ['New'],
    todo:         ['To-Do', 'To Do', 'ToDo'],
    returned:     ['Returned'],
    in_progress:  ['In Progress'],
    feedback:     ['Feedback'],
    review:       ['Review'],
    ready_merge:  ['Ready to Merge', 'Ready to merge'],
    final_check:  ['Final Check'],
    done:         ['Done', 'Closed'],
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
    scope = @project.issues.includes(:status, :author, :assigned_to, :tracker)
    scope = scope.where(tracker_id: @tracker_id) if @tracker_id
    scope = scope.where(assigned_to_id: @assignee_id) if @assignee_id

    if @date_from || @date_to
      scope = scope.where('issues.created_on >= ?', @date_from.beginning_of_day) if @date_from
      scope = scope.where('issues.created_on <= ?', @date_to.end_of_day) if @date_to
    end

    issues = scope.to_a
    all_transitions = load_transitions(issues)

    issues.map do |issue|
      transitions = all_transitions[issue.id] || []
      durations = calculate_durations_from_transitions(transitions)

      {
        issue: issue,
        durations: durations
      }
    end
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

    d1 = v.call(:new).sum { |p| hours.call(p[:enter], p[:exit]) }

    todo_visits = v.call(:todo)
    returned_visits = v.call(:returned)

    d2 = todo_visits[0] ? hours.call(todo_visits[0][:enter], todo_visits[0][:exit]) : 0.0

    d2aug =
      (todo_visits[1..] || []).sum { |p| hours.call(p[:enter], p[:exit]) } +
      returned_visits.sum { |p| hours.call(p[:enter], p[:exit]) }

    ip_visits = v.call(:in_progress)
    d3    = ip_visits[0] ? hours.call(ip_visits[0][:enter], ip_visits[0][:exit]) : 0.0
    d3aug = (ip_visits[1..] || []).sum { |p| hours.call(p[:enter], p[:exit]) }

    fb_visits = v.call(:feedback)
    d4    = fb_visits[0] ? hours.call(fb_visits[0][:enter], fb_visits[0][:exit]) : 0.0
    d4aug = (fb_visits[1..] || []).sum { |p| hours.call(p[:enter], p[:exit]) }

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

    fc_vis = v.call(:final_check)
    d7aug  = fc_vis.sum { |p| hours.call(p[:enter], p[:exit]) }

    last_fc    = fc_vis.last
    done_vis   = v.call(:done)
    first_done = done_vis[0]
    d7 = last_fc && first_done ? hours.call(last_fc[:exit], first_done[:enter]) : 0.0

    c1 = c2 = c3 = c4 = 0

    # Direct returns back to In Progress
    periods.each_cons(2) do |a, b|
      next unless status_role(b[:status]) == :in_progress

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

    # Indirect returns via Returned -> In Progress
    periods.each_cons(3) do |a, b, c|
      next unless status_role(b[:status]) == :returned
      next unless status_role(c[:status]) == :in_progress

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

    total = d1 + d2 + d2aug + d3 + d3aug + d4 + d4aug + d5 + d5aug + d6 + d6aug + d7aug + d7

    {
      D1: d1, D2: d2, D2aug: d2aug,
      D3: d3, D3aug: d3aug,
      D4: d4, D4aug: d4aug,
      D5: d5, D5aug: d5aug,
      D6: d6, D6aug: d6aug,
      D7aug: d7aug, D7: d7,
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
      D7aug: 0.0, D7: 0.0,
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
    d_fields = %w[D1 D2 D2aug D3 D3aug D4 D4aug D5 D5aug D6 D6aug D7aug D7 TOTAL C1 C2 C3 C4]
    CSV.generate(headers: true, encoding: 'UTF-8') do |csv|
      csv << ['issue_id', 'subject', 'status', 'assignee', 'tracker', *d_fields]
      issues_data.each do |item|
        iss = item[:issue]
        dur = item[:durations]
        csv << [
          iss.id, iss.subject, iss.status.name,
          iss.assigned_to&.name, iss.tracker.name,
          *d_fields.map { |f| dur[f.to_sym] || 0 }
        ]
      end
    end
  end
end
