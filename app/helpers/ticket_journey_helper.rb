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
    query.inline_columns.reject { |column| %w[id subject status].include?(column.name.to_s) }
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
      { key: :D1, label: 'D1', aug: false, desc: 'Planning (New -> To-Do)' },
      { key: :D2, label: 'D2', aug: false, desc: 'Wait for Dev (1st)' },
      { key: :D2aug, label: 'D2-aug', aug: true, desc: 'Wait for Dev (returns)' },
      { key: :D3, label: 'D3', aug: false, desc: 'Under Development (1st)' },
      { key: :D3aug, label: 'D3-aug', aug: true, desc: 'Under Dev (subsequent)' },
      { key: :D4, label: 'D4', aug: false, desc: 'QA Time (1st)' },
      { key: :D4aug, label: 'D4-aug', aug: true, desc: 'QA Time (returns)' },
      { key: :D5, label: 'D5', aug: false, desc: 'Review -> Ready to Merge' },
      { key: :D5aug, label: 'D5-aug', aug: true, desc: 'Review -> Returned' },
      { key: :D6, label: 'D6', aug: false, desc: 'Ready to Merge -> Final Check' },
      { key: :D6aug, label: 'D6-aug', aug: true, desc: 'Ready to Merge -> Returned' },
      { key: :D7aug, label: 'D7-aug', aug: true, desc: 'Final Check -> Returned' },
      { key: :D7, label: 'D7', aug: false, desc: 'Final Check -> Done / Closed' },
      { key: :D8, label: 'D8', aug: false, desc: 'New -> Feedback' },
      { key: :D9, label: 'D9', aug: false, desc: 'Feedback -> New' },
      { key: :D10, label: 'D10', aug: false, desc: 'Feedback -> Archived' }
    ]
  end

  def supplemental_duration_fields
    [
      { key: :ON_HOLD, label: 'On-Hold', aug: false, desc: 'Paused Time (On-Hold)', css_class: 'tj-th-hold' }
    ]
  end

  def duration_fields_for_family(family_key)
    base_fields =
      case family_key.to_sym
      when :customer_support
        [
          { key: :DC1, label: 'DC1', aug: false, desc: 'New -> Review' },
          { key: :DC2, label: 'DC2', aug: false, desc: 'Review -> Pending' },
          { key: :DC3, label: 'DC3', aug: false, desc: 'Review -> In Progress' },
          { key: :DC4, label: 'DC4', aug: false, desc: 'Review -> Done / Closed' },
          { key: :DC5, label: 'DC5', aug: false, desc: 'Pending -> In Progress' },
          { key: :DC6, label: 'DC6', aug: false, desc: 'Pending -> Done / Closed' },
          { key: :DC7, label: 'DC7', aug: false, desc: 'In Progress -> Done / Closed' }
        ]
      when :task
        [
          { key: :DT1, label: 'DT1', aug: false, desc: 'New -> To-Do' },
          { key: :DT2, label: 'DT2', aug: false, desc: 'To-Do -> In Progress' },
          { key: :DT2aug, label: 'DT2-aug', aug: true, desc: 'Returned -> In Progress' },
          { key: :DT3, label: 'DT3', aug: false, desc: 'In Progress (1st) -> Feedback' },
          { key: :DT3aug, label: 'DT3-aug', aug: true, desc: 'In Progress (next) -> Feedback' },
          { key: :DT4, label: 'DT4', aug: false, desc: 'Feedback -> Final Check' },
          { key: :DT4aug, label: 'DT4-aug', aug: true, desc: 'Feedback -> Returned' },
          { key: :DT5, label: 'DT5', aug: false, desc: 'Final Check -> Done / Closed' },
          { key: :DT5aug, label: 'DT5-aug', aug: true, desc: 'Final Check -> Returned' }
        ]
      when :container
        [
          { key: :DP1, label: 'DP1', aug: false, desc: 'New -> To-Do' },
          { key: :DP2, label: 'DP2', aug: false, desc: 'To-Do -> In Progress' },
          { key: :DP3, label: 'DP3', aug: false, desc: 'In Progress -> Final Check' },
          { key: :DP4, label: 'DP4', aug: false, desc: 'Final Check -> Done / Closed' }
        ]
      else
        d_fields
      end

    base_fields + supplemental_duration_fields
  end

  def section_table_column_count(query, family_key)
    5 + visible_native_query_columns(query).size + duration_fields_for_family(family_key).size + counter_definitions(family_key).size
  end

  def duration_header_css_class(field)
    return field[:css_class] if field[:css_class].present?

    field[:aug] ? 'tj-th-aug' : 'tj-th-d'
  end

  def peak_duration_field(durations, family_key = :internal)
    fields = duration_fields_for_family(family_key).reject { |field| field[:key] == :ON_HOLD }
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
    base += ' tj-dur-high' if hours.to_f > 48
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
