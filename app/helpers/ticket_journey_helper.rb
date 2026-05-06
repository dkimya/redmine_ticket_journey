module TicketJourneyHelper
  def duration_report_params(query)
    query_params = query.as_params.deep_dup.deep_stringify_keys

    %w[report_sort report_dir report_family].each do |key|
      query_params.delete(key)
      value = params[key]
      query_params[key] = value if value.present?
    end

    query_params
  end

  def owner_returns_params(query)
    query_params = query.as_params.deep_dup.deep_stringify_keys

    %w[ticket_owner_role_id owner_sort owner_dir].each do |key|
      query_params.delete(key)
      value = params[key]
      query_params[key] = value if value.present?
    end

    query_params
  end

  def flow_report_params(query)
    query_params = query.as_params.deep_dup.deep_stringify_keys

    %w[flow_start_date flow_end_date ticket_owner_role_id].each do |key|
      query_params.delete(key)
      value = params[key]
      query_params[key] = value if value.present?
    end

    query_params
  end

  def project_health_params(query)
    query.as_params.deep_dup.deep_stringify_keys
  end

  def release_readiness_params(query)
    query_params = query.as_params.deep_dup.deep_stringify_keys

    %w[release_sort release_dir].each do |key|
      query_params.delete(key)
      value = params[key]
      query_params[key] = value if value.present?
    end

    query_params
  end

  def release_readiness_sort_link(query, sort_key, caption, title: nil)
    current_key = params[:release_sort].to_s
    current_dir = params[:release_dir].to_s
    current_dir = (%w[name project status due_date].include?(sort_key.to_s) ? 'asc' : 'desc') unless %w[asc desc].include?(current_dir)
    default_dir = %w[name project status due_date].include?(sort_key.to_s) ? 'asc' : 'desc'
    next_dir = current_key == sort_key.to_s && current_dir == default_dir ? (default_dir == 'asc' ? 'desc' : 'asc') : default_dir

    indicator =
      if current_key == sort_key.to_s
        current_dir == 'asc' ? ' ^' : ' v'
      else
        ''
      end

    link_to(
      "#{caption}#{indicator}",
      ticket_journey_release_readiness_path(@project, release_readiness_params(query).merge('release_sort' => sort_key.to_s, 'release_dir' => next_dir)),
      title: title
    )
  end

  def bug_analysis_params(query)
    query_params = query.as_params.deep_dup.deep_stringify_keys

    %w[bug_start_date bug_end_date bug_sort bug_dir].each do |key|
      query_params.delete(key)
      value = params[key]
      query_params[key] = value if value.present?
    end

    query_params
  end

  def bug_analysis_sort_link(query, sort_key, caption, title: nil)
    current_key = params[:bug_sort].to_s
    current_dir = params[:bug_dir].to_s
    current_dir = (sort_key.to_s == 'reason' ? 'asc' : 'desc') unless %w[asc desc].include?(current_dir)
    default_dir = sort_key.to_s == 'reason' ? 'asc' : 'desc'
    next_dir = current_key == sort_key.to_s && current_dir == default_dir ? (default_dir == 'asc' ? 'desc' : 'asc') : default_dir

    indicator =
      if current_key == sort_key.to_s
        current_dir == 'asc' ? ' ^' : ' v'
      else
        ''
      end

    link_to(
      "#{caption}#{indicator}",
      ticket_journey_bug_analysis_path(@project, bug_analysis_params(query).merge('bug_sort' => sort_key.to_s, 'bug_dir' => next_dir)),
      title: title
    )
  end

  def bug_analysis_issue_filter_params(row, scope)
    filters = %w[tracker_id]
    operators = { 'tracker_id' => '=' }
    values = { 'tracker_id' => bug_tracker_filter_values }
    add_bug_source_filter(filters, operators, values, row[:reason])

    case scope.to_sym
    when :found
      add_date_filter(filters, operators, values, 'created_on', '><', [@bug_start_date, @bug_end_date])
    when :closed
      add_date_filter(filters, operators, values, 'closed_on', '><', [@bug_start_date, @bug_end_date])
    when :remaining, :impact
      add_status_filter(filters, operators, values, 'o')
      add_date_filter(filters, operators, values, 'created_on', '<=', [@bug_end_date])
    when :beginning
      add_status_filter(filters, operators, values, 'o')
      add_date_filter(filters, operators, values, 'created_on', '<=', [@bug_start_date])
    end

    {
      set_filter: '1',
      f: filters,
      op: operators,
      v: values
    }
  end

  def bug_analysis_count_link(row, scope, value)
    return '-' if value.to_i.zero?

    link_to(
      value,
      project_issues_path(@project, bug_analysis_issue_filter_params(row, scope)),
      class: 'tj-drilldown-link',
      title: 'Open matching issues'
    )
  end

  def bug_tracker_filter_values
    @bug_tracker_filter_values ||= Tracker.where(name: 'Bug').pluck(:id).map(&:to_s)
  end

  def release_readiness_issue_filter_params(row, scope)
    filters = %w[fixed_version_id]
    operators = { 'fixed_version_id' => '=' }
    values = { 'fixed_version_id' => [row[:id].to_s] }

    case scope.to_sym
    when :open
      add_status_filter(filters, operators, values, 'o')
    when :done
      add_status_filter(filters, operators, values, 'c')
    when :stopped
      add_exact_status_filter(filters, operators, values, stopped_status_filter_values)
    when :overdue
      add_status_filter(filters, operators, values, 'o')
      add_date_filter(filters, operators, values, 'due_date', '<=', [User.current.today])
    when :no_owner
      add_status_filter(filters, operators, values, 'o')
      add_missing_filter(filters, operators, values, "cf_#{TicketJourneyController::TICKET_OWNER_CF_ID}")
    when :no_due_date
      add_status_filter(filters, operators, values, 'o')
      add_missing_filter(filters, operators, values, 'due_date')
    when :priority_open
      add_status_filter(filters, operators, values, 'o')
      add_priority_filter(filters, operators, values)
    end

    {
      set_filter: '1',
      f: filters,
      op: operators,
      v: values
    }
  end

  def release_readiness_count_link(row, scope, value)
    return '-' if value.to_i.zero?

    link_to(
      value,
      project_issues_path(@project, release_readiness_issue_filter_params(row, scope)),
      class: 'tj-drilldown-link',
      title: 'Open matching issues'
    )
  end

  def release_readiness_no_target_filter_params
    filters = %w[status_id fixed_version_id]
    operators = { 'status_id' => 'o', 'fixed_version_id' => '!*' }
    values = { 'status_id' => [''], 'fixed_version_id' => [''] }

    {
      set_filter: '1',
      f: filters,
      op: operators,
      v: values
    }
  end

  def stopped_status_filter_values
    @stopped_status_filter_values ||= IssueStatus.where(name: ['Pending', 'On-Hold']).pluck(:id).map(&:to_s)
  end

  def priority_filter_values
    @priority_filter_values ||= IssuePriority.where("LOWER(name) LIKE ? OR LOWER(name) LIKE ?", '%urgent%', '%immediate%').pluck(:id).map(&:to_s)
  end

  def add_bug_source_filter(filters, operators, values, reason)
    field_name = "cf_#{TicketJourneyController::BUG_SOURCE_CF_ID}"
    filters << field_name

    if reason.to_s == 'No Bug Source'
      operators[field_name] = '!*'
      values[field_name] = ['']
    else
      operators[field_name] = '='
      values[field_name] = [reason.to_s]
    end
  end

  def add_status_filter(filters, operators, values, operator)
    filters << 'status_id'
    operators['status_id'] = operator
    values['status_id'] = ['']
  end

  def add_exact_status_filter(filters, operators, values, status_ids)
    filters << 'status_id'
    operators['status_id'] = '='
    values['status_id'] = status_ids.presence || ['0']
  end

  def add_missing_filter(filters, operators, values, field_name)
    filters << field_name
    operators[field_name] = '!*'
    values[field_name] = ['']
  end

  def add_priority_filter(filters, operators, values)
    filters << 'priority_id'
    operators['priority_id'] = '='
    values['priority_id'] = priority_filter_values.presence || ['0']
  end

  def add_date_filter(filters, operators, values, field_name, operator, date_values)
    filters << field_name
    operators[field_name] = operator
    values[field_name] = date_values.map { |date| date.respond_to?(:strftime) ? date.strftime('%Y-%m-%d') : date.to_s }
  end

  def issue_detail_params(query, issue)
    duration_report_params(query).merge('issue_id' => issue.id, 'view' => 'detail')
  end

  def issue_detail_tab_params(query)
    duration_report_params(query).except('issue_id').merge('view' => 'detail')
  end

  def query_sort_link(query, column, caption = nil)
    column_name = column.respond_to?(:name) ? column.name.to_s : column.to_s
    column_caption = caption || (column.respond_to?(:caption) ? column.caption.to_s : column_name.humanize)
    current_key = query.sort_criteria.first&.first.to_s
    current_order = query.sort_criteria.first&.last.to_s
    next_order = (current_key == column_name && current_order == 'asc') ? 'desc' : 'asc'

    indicator =
      if current_key == column_name
        current_order == 'asc' ? ' ^' : ' v'
      else
        ''
      end

    return "#{column_caption}#{indicator}" unless !column.respond_to?(:sortable?) || column.sortable?

    sort_params = duration_report_params(query)
    sort_params.delete('report_sort')
    sort_params.delete('report_dir')
    sort_params.delete('report_family')

    link_to(
      "#{column_caption}#{indicator}",
      ticket_journey_path(@project, sort_params.merge('sort' => "#{column_name}:#{next_order}"))
    )
  end

  def report_sort_link(query, family_key, sort_key, caption, title: nil)
    current_key = params[:report_sort].to_s
    current_family = params[:report_family].to_s
    current_dir = params[:report_dir].to_s
    current_dir = 'desc' unless %w[asc desc].include?(current_dir)
    same_sort = current_key == sort_key.to_s && current_family == family_key.to_s
    next_dir = same_sort && current_dir == 'desc' ? 'asc' : 'desc'

    indicator =
      if same_sort
        current_dir == 'asc' ? ' ^' : ' v'
      else
        ''
      end

    link_to(
      "#{caption}#{indicator}",
      ticket_journey_path(@project, duration_report_params(query).merge('report_family' => family_key.to_s, 'report_sort' => sort_key.to_s, 'report_dir' => next_dir)),
      title: title
    )
  end

  def owner_returns_sort_link(query, sort_key, caption, title: nil)
    current_key = params[:owner_sort].to_s
    current_dir = params[:owner_dir].to_s
    current_dir = (sort_key.to_s == 'owner' ? 'asc' : 'desc') unless %w[asc desc].include?(current_dir)
    default_dir = sort_key.to_s == 'owner' ? 'asc' : 'desc'
    next_dir = current_key == sort_key.to_s && current_dir == default_dir ? (default_dir == 'asc' ? 'desc' : 'asc') : default_dir

    indicator =
      if current_key == sort_key.to_s
        current_dir == 'asc' ? ' ^' : ' v'
      else
        ''
      end

    link_to(
      "#{caption}#{indicator}",
      ticket_journey_owner_returns_path(@project, owner_returns_params(query).merge('owner_sort' => sort_key.to_s, 'owner_dir' => next_dir)),
      title: title
    )
  end

  def visible_native_query_columns(query)
    query.inline_columns.reject { |column| %w[id subject].include?(column.name.to_s) }
  end

  def ticket_owner_filter_params(query, owner_value)
    query_params = query.as_params.deep_dup
    filters = Array(query_params[:f] || query_params['f']).map(&:to_s)
    operators = (query_params[:op] || query_params['op'] || {}).deep_dup
    values = (query_params[:v] || query_params['v'] || {}).deep_dup
    field_name = "cf_#{TicketJourneyController::TICKET_OWNER_CF_ID}"
    filters << field_name unless filters.include?(field_name)

    if owner_value.present?
      operators[field_name] = '='
      values[field_name] = [owner_value.to_s]
    else
      operators[field_name] = '!*'
      values[field_name] = ['']
    end

    query_params[:set_filter] = '1'
    query_params[:f] = filters
    query_params[:op] = operators
    query_params[:v] = values
    query_params
  end

  def grouped_issues_data(query, issues_data)
    group_column = query.group_by_column
    return [[nil, issues_data]] unless group_column

    issues_data.group_by do |item|
      value = group_column.value_object(item[:issue])
      value = value.name if value.respond_to?(:name)
      value = value.to_s if value.is_a?(Date) || value.is_a?(Time)
      value.presence || 'None'
    end.sort_by { |label, _| label.to_s.downcase }
  end

  def group_label(query, label, count)
    return nil unless query.group_by_column

    "#{query.group_by_column.caption}: #{label} (#{count})"
  end

  def section_summary(items)
    totals = items.map { |item| item[:durations][:TOTAL].to_f }.reject(&:zero?)

    {
      issues: items.size,
      avg_total: totals.any? ? (totals.sum / totals.size) : 0.0,
      max_total: totals.max || 0.0,
      returns: items.sum { |item| total_returns(item[:durations]) }
    }
  end

  def total_returns(durations)
    %i[C1 C2 C3 C4].sum { |key| durations[key].to_i }
  end

  def counter_definitions(family_key = :internal)
    case family_key.to_sym
    when :task
      [
        { key: :C1, code: 'R1', short_label: 'Output Quality Rejection', title: 'Output Quality Rejection', transition: 'Feedback -> Returned' },
        { key: :C4, code: 'R4', short_label: 'Final Check Rejection', title: 'Final Check Rejection', transition: 'Final Check -> Returned' }
      ]
    when :internal
      [
        { key: :C1, code: 'R1', short_label: 'Function-Fail / Granular Error', title: 'Function-Fail / Granular Error', transition: 'Feedback -> Returned' },
        { key: :C2, code: 'R2', short_label: 'Code Quality Fail', title: 'Code Quality Fail', transition: 'Review -> Returned' },
        { key: :C3, code: 'R3', short_label: 'Merge Conflict Error', title: 'Merge Conflict Error', transition: 'Ready to Merge -> Returned' },
        { key: :C4, code: 'R4', short_label: 'E2E Fail / Side-Effect Error', title: 'E2E Fail / Side-Effect Error', transition: 'Final Check -> Returned' }
      ]
    else
      []
    end
  end

  def d_fields
    [
      { key: :D0, label: 'D0', aug: false, desc: 'Planning (New -> To-Do)', counted_in_total: false },
      { key: :D0aug, label: 'D0-aug', aug: true, desc: 'Unnecessary Ticket Identification (New -> Archived)', counted_in_total: false },
      { key: :D1, label: 'D1', aug: false, desc: 'Wait for Dev (To-Do -> In Progress)' },
      { key: :D1aug, label: 'D1-aug', aug: true, desc: 'Wait for Dev (Returned -> In Progress)' },
      { key: :D2, label: 'D2', aug: false, desc: 'Under Development (In Progress -> Feedback)' },
      { key: :D2aug, label: 'D2-aug', aug: true, desc: 'Under Development (re-do)' },
      { key: :D3, label: 'D3', aug: false, desc: 'QA Time (Feedback -> Review)' },
      { key: :D3aug, label: 'D3-aug', aug: true, desc: 'QA Time (Feedback -> Returned)' },
      { key: :D4, label: 'D4', aug: false, desc: 'Review Time (Review -> Ready to Merge)' },
      { key: :D4aug, label: 'D4-aug', aug: true, desc: 'Review Time (Review -> Returned)' },
      { key: :D5, label: 'D5', aug: false, desc: 'Merging Time (Ready to Merge -> Final Check)' },
      { key: :D5aug, label: 'D5-aug', aug: true, desc: 'Merging Time (Ready to Merge -> Returned)' },
      { key: :D6, label: 'D6', aug: false, desc: 'Post-Integration Test Time (Final Check -> Done / Closed)' },
      { key: :D6aug, label: 'D6-aug', aug: true, desc: 'Post-Integration Test Time (Final Check -> Returned)' },
      { key: :D7, label: 'D7', aug: false, desc: 'Waiting for Validation (New -> Feedback)' },
      { key: :D8, label: 'D8', aug: false, desc: 'Validation Time (Feedback -> New)' },
      { key: :D9, label: 'D9', aug: false, desc: 'Not-Validation (Feedback -> Archived)' }
    ]
  end

  def on_hold_field
    { key: :ON_HOLD, label: 'On-Hold', aug: false, desc: 'Paused Time (On-Hold)', css_class: 'tj-th-hold' }
  end

  def pending_field
    { key: :PENDING, label: 'Pending', aug: false, desc: 'Paused Time (Pending)', css_class: 'tj-th-hold' }
  end

  def calendar_total_field(family_key = nil)
    desc =
      case family_key.to_sym
      when :internal
        'Cycle Total + D0 + D0-aug + On-Hold + Pending'
      when :task
        'Cycle Total + DT0 + On-Hold + Pending'
      when :container
        'Cycle Total + DP0 + On-Hold + Pending'
      when :customer_support
        'Cycle Total + DC0 + DC1 + On-Hold'
      else
        'Cycle Total + On-Hold + Pending'
      end

    { key: :CALENDAR_TOTAL, label: 'Calendar Total', aug: false, desc: desc, css_class: 'tj-th-total' }
  end

  def supplemental_duration_fields_for_family(family_key)
    fields = [on_hold_field]
    fields << pending_field unless family_key.to_sym == :customer_support
    fields
  end

  def duration_fields_for_family(family_key)
    base_fields =
      case family_key.to_sym
      when :customer_support
        [
          { key: :DC0, label: 'DC0', aug: false, desc: 'Customer Inquiry Waiting Time (New -> Review)', counted_in_total: false },
          { key: :DC1, label: 'DC1', aug: false, desc: 'Unnecessary Support Ticket Identification (Review/New -> Archived)', counted_in_total: false },
          { key: :DC2, label: 'DC2', aug: false, desc: 'Getting Quote for Ticket (Review -> Feedback)' },
          { key: :DC3, label: 'DC3', aug: false, desc: 'Review -> In Progress' },
          { key: :DC4, label: 'DC4', aug: false, desc: 'Review -> Done / Closed' },
          { key: :DC5, label: 'DC5', aug: false, desc: 'Decision Making (Feedback -> In Progress)' },
          { key: :DC6, label: 'DC6', aug: false, desc: 'Closure Time (Feedback -> Done / Closed)' },
          { key: :DC7, label: 'DC7', aug: false, desc: 'In Progress -> Done / Closed' }
        ]
      when :task
        [
          { key: :DT0, label: 'DT0', aug: false, desc: 'Planning (New -> To-Do)', counted_in_total: false },
          { key: :DT1, label: 'DT1', aug: false, desc: 'Wait for Job to Start (To-Do -> In Progress)' },
          { key: :DT1aug, label: 'DT1-aug', aug: true, desc: 'Wait for Job to be Done (Returned -> In Progress)' },
          { key: :DT2, label: 'DT2', aug: false, desc: 'Under Work (In Progress -> Feedback)' },
          { key: :DT2aug, label: 'DT2-aug', aug: true, desc: 'Under Work (re-do)' },
          { key: :DT3, label: 'DT3', aug: false, desc: 'Feedback Time (Feedback -> Final Check)' },
          { key: :DT3aug, label: 'DT3-aug', aug: true, desc: 'Feedback Time (Feedback -> Returned)' },
          { key: :DT4, label: 'DT4', aug: false, desc: 'Final Review & Check Time (Final Check -> Done / Closed)' },
          { key: :DT4aug, label: 'DT4-aug', aug: true, desc: 'Final Review & Check Time (Final Check -> Returned)' }
        ]
      when :container
        [
          { key: :DP0, label: 'DP0', aug: false, desc: 'Initiation Time (New -> To-Do)', counted_in_total: false },
          { key: :DP1, label: 'DP1', aug: false, desc: 'Planning Time (To-Do -> In Progress)' },
          { key: :DP2, label: 'DP2', aug: false, desc: 'Execution Time (In Progress -> Final Check)' },
          { key: :DP3, label: 'DP3', aug: false, desc: 'Pre-Closure Check (Final Check -> Done / Closed)' }
        ]
      else
        d_fields
      end

    base_fields
  end

  def section_table_column_count(query, family_key)
    5 + visible_native_query_columns(query).size + duration_fields_for_family(family_key).size + supplemental_duration_fields_for_family(family_key).size + counter_definitions(family_key).size
  end

  def duration_header_css_class(field)
    return field[:css_class] if field[:css_class].present?

    field[:aug] ? 'tj-th-aug' : 'tj-th-d'
  end

  def duration_group_css_class(field, fields, index)
    classes = []
    is_precycle = field[:counted_in_total] == false

    if is_precycle
      next_field = fields[index + 1]
      classes << 'tj-precycle-col'
      classes << 'tj-precycle-end' unless next_field && next_field[:counted_in_total] == false
    end

    classes.join(' ')
  end

  def peak_duration_field(durations, family_key = :internal)
    fields = duration_fields_for_family(family_key)
    fields.map { |field| [field, durations[field[:key]].to_f] }.max_by { |field, value| [value, -fields.index(field)] }
  end

  def peak_duration_label(durations, family_key = :internal)
    field, value = peak_duration_field(durations, family_key)
    return '-' if field.nil? || value.to_f <= 0

    "#{field[:label]} #{format_hours(value)}"
  end

  def format_hours(hours)
    return '-' if hours.nil? || hours == 0

    total_minutes = (hours.to_f * 60).round
    days = total_minutes / (60 * 24)
    hour_count = (total_minutes % (60 * 24)) / 60
    minutes = total_minutes % 60
    parts = []
    parts << "#{days}d" if days > 0
    parts << "#{hour_count}h" if hour_count > 0
    parts << "#{minutes}m" if minutes > 0 && days == 0
    parts.empty? ? '0m' : parts.join(' ')
  end

  def duration_css_class(hours, aug: false)
    return 'tj-dur-zero' if hours.nil? || hours == 0

    base = aug ? 'tj-dur-aug' : 'tj-dur'
    base += ' tj-dur-high' if hours.to_f > 240
    base
  end

  def counter_css_class(count)
    count.to_i > 0 ? 'tj-counter-active' : 'tj-counter-zero'
  end

  def format_percentage(numerator, denominator)
    return '-' if denominator.to_f <= 0

    "#{((numerator.to_f / denominator.to_f) * 100).round(1)}%"
  end
end
