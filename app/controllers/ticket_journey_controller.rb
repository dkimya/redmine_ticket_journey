class TicketJourneyController < ApplicationController
  before_action :find_project
  before_action :authorize

  # ---------------------------------------------------------------
  # INDEX — list all issues with computed durations
  # ---------------------------------------------------------------
  def index
    @date_from = params[:date_from].present? ? Date.parse(params[:date_from]) rescue nil : nil
    @date_to   = params[:date_to].present?   ? Date.parse(params[:date_to])   rescue nil : nil
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
    @issue = Issue.find(params[:id])
    return render_403 unless @issue.project == @project

    @duration_data = compute_issue_durations(@issue)
    @transitions   = load_transitions(@issue)
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
    in_progress:  ['In Progress'],
    feedback:     ['Feedback'],
    review:       ['Review'],
    ready_merge:  ['Ready to Merge', 'Ready to merge'],
    final_check:  ['Final Check'],
    done:         ['Done', 'Closed'],
  }.freeze

  def statuses_by_role
    @statuses_by_role ||= begin
      all = IssueStatus.all.index_by { |s| s.name.downcase.strip }
      STATUS_NAMES.transform_values do |names|
        names.filter_map { |n| all[n.downcase.strip]&.id }
      end
    end
  end

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
      issue_ids = [scope_or_issue.id]
    else
      issue_ids = scope_or_issue.pluck(:id)
    end
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
      JOIN users u ON u.id = j.user_id
      WHERE i.id IN (#{issue_ids.join(',')})
      ORDER BY i.id, j.created_on ASC
    SQL

    # Group transitions by issue_id, prepend a synthetic "created" event
    by_issue = Hash.new { |h, k| h[k] = [] }

    # Add creation event per issue
    if scope_or_issue.is_a?(Issue)
      issues_list = [scope_or_issue]
    else
      issues_list = scope_or_issue.to_a
    end

    issues_list.each do |iss|
      by_issue[iss.id] << {
        issue_id:      iss.id,
        issue_subject: iss.subject,
        changed_at:    iss.created_on,
        from_status:   nil,
        to_status:     iss.status.name,
        changed_by:    iss.author.login,
        changed_by_name: iss.author.name,
        synthetic:     true
      }
    end

    rows.each do |row|
      id = row['issue_id'].to_i
      by_issue[id] << {
        issue_id:        id,
        issue_subject:   row['issue_subject'],
        changed_at:      row['changed_at'].is_a?(String) ? Time.parse(row['changed_at']) : row['changed_at'],
        from_status:     row['from_status'],
        to_status:       row['to_status'],
        changed_by:      row['changed_by'],
        changed_by_name: "#{row['changed_by_firstname']} #{row['changed_by_lastname']}".strip,
        synthetic:       false
      }
    end

    by_issue
  end

  # ---------------------------------------------------------------
  # COMPUTE DURATIONS FOR ALL ISSUES
  # ---------------------------------------------------------------
  def compute_all_durations
    scope = @project.issues.includes(:status, :author, :assigned_to, :tracker)
    scope = scope.where(tracker_id: @tracker_id)     if @tracker_id
    scope = scope.where(assigned_to_id: @assignee_id) if @assignee_id
    if @date_from || @date_to
      scope = scope.where('issues.created_on >= ?', @date_from.beginning_of_day) if @date_from
      scope = scope.where('issues.created_on <= ?', @date_to.end_of_day)         if @date_to
    end

    all_transitions = load_transitions(scope)

    scope.map do |issue|
      transitions = all_transitions[issue.id] || []
      durations   = calculate_durations_from_transitions(transitions)
      {
        issue:    issue,
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

    # Build periods: [{status, enter, exit}]
    periods = build_periods(transitions)

    # Categorise each period by role
    # D1: time in NEW
    # D2: time in TODO (first visit)
    # D2aug: time in TODO (subsequent visits) — accumulated
    # D3: time in IN_PROGRESS (first visit)
    # D3aug: time in IN_PROGRESS (subsequent visits) — accumulated
    # D4: time in FEEDBACK (first visit)
    # D4aug: time in FEEDBACK (subsequent visits) — accumulated
    # D5aug: time in REVIEW (first visit = code review time)
    # D5: wait gap between last FEEDBACK exit and first REVIEW enter (vertical pass)
    # D6aug: time in REVIEW (subsequent) — actually = Ready-to-Merge duration
    # D6: wait gap between last REVIEW exit and READY_MERGE enter
    # D6aug: time in READY_MERGE
    # D7aug: time in FINAL_CHECK
    # D7: wait gap FINAL_CHECK exit → DONE enter

    visit_index = Hash.new(0)
    visits      = Hash.new { |h, k| h[k] = [] }

    periods.each do |p|
      role = status_role(p[:status])
      visit_index[role] += 1
      p[:visit] = visit_index[role]
      visits[role] << p
    end

    hours = ->(a, b) { a && b ? [(b - a) / 3600.0, 0].max.round(2) : 0.0 }

    # D1
    d1 = visits[:new].sum  { |p| hours.call(p[:enter], p[:exit]) }

    # D2 / D2aug
    todo_visits = visits[:todo]
    d2    = todo_visits[0] ? hours.call(todo_visits[0][:enter], todo_visits[0][:exit]) : 0.0
    d2aug = todo_visits[1..].sum { |p| hours.call(p[:enter], p[:exit]) }

    # D3 / D3aug
    ip_visits = visits[:in_progress]
    d3    = ip_visits[0] ? hours.call(ip_visits[0][:enter], ip_visits[0][:exit]) : 0.0
    d3aug = ip_visits[1..].sum { |p| hours.call(p[:enter], p[:exit]) }

    # D4 / D4aug
    fb_visits = visits[:feedback]
    d4    = fb_visits[0] ? hours.call(fb_visits[0][:enter], fb_visits[0][:exit]) : 0.0
    d4aug = fb_visits[1..].sum { |p| hours.call(p[:enter], p[:exit]) }

    # D5 (gap: last feedback exit → first review enter)
    last_fb  = fb_visits.last
    rev_vis  = visits[:review]
    first_rev = rev_vis[0]
    d5 = last_fb && first_rev ? hours.call(last_fb[:exit], first_rev[:enter]) : 0.0

    # D5aug: first review duration
    d5aug = first_rev ? hours.call(first_rev[:enter], first_rev[:exit]) : 0.0

    # D6 (gap: last review exit → ready_merge enter)
    last_rev = rev_vis.last
    rm_vis   = visits[:ready_merge]
    first_rm = rm_vis[0]
    d6 = last_rev && first_rm ? hours.call(last_rev[:exit], first_rm[:enter]) : 0.0

    # D6aug: ready_merge duration
    d6aug = rm_vis.sum { |p| hours.call(p[:enter], p[:exit]) }

    # D7aug: final_check duration
    fc_vis = visits[:final_check]
    d7aug  = fc_vis.sum { |p| hours.call(p[:enter], p[:exit]) }

    # D7 (gap: last final_check exit → done enter)
    last_fc   = fc_vis.last
    done_vis  = visits[:done]
    first_done = done_vis[0]
    d7 = last_fc && first_done ? hours.call(last_fc[:exit], first_done[:enter]) : 0.0

    # Return counters (transitions back to IN_PROGRESS from downstream)
    c1 = c2 = c3 = c4 = 0
    periods.each_cons(2) do |a, b|
      next unless status_role(b[:status]) == :in_progress
      case status_role(a[:status])
      when :feedback    then c1 += 1
      when :review      then c2 += 1
      when :ready_merge then c3 += 1
      when :final_check then c4 += 1
      end
    end

    total = d1 + d2 + d2aug + d3 + d3aug + d4 + d4aug + d5 + d5aug + d6 + d6aug + d7aug + d7

    {
      D1:     d1,    D2:    d2,    D2aug: d2aug,
      D3:     d3,    D3aug: d3aug,
      D4:     d4,    D4aug: d4aug,
      D5:     d5,    D5aug: d5aug,
      D6:     d6,    D6aug: d6aug,
      D7aug:  d7aug, D7:    d7,
      TOTAL:  total,
      C1: c1, C2: c2, C3: c3, C4: c4,
      periods: periods
    }
  end

  def build_periods(transitions)
    sorted = transitions.sort_by { |t| t[:changed_at] }
    periods = []

    sorted.each_with_index do |t, i|
      next_t = sorted[i + 1]
      status = t[:to_status]
      next if status.nil?
      enter = t[:changed_at]
      exit_t = next_t ? next_t[:changed_at] : Time.current
      periods << { status: status, enter: enter, exit: exit_t }
    end

    # Merge consecutive same-status periods
    merged = []
    periods.each do |p|
      last = merged.last
      if last && last[:status] == p[:status]
        last[:exit] = p[:exit]
      else
        merged << p.dup
      end
    end
    merged
  end

  def empty_durations
    keys = %i[D1 D2 D2aug D3 D3aug D4 D4aug D5 D5aug D6 D6aug D7aug D7 TOTAL C1 C2 C3 C4]
    keys.each_with_object({}) { |k, h| h[k] = 0.0 }.merge(periods: [])
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
