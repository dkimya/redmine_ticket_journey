module TicketJourneyHelper
  def query_sort_link(query, column, caption=nil)
    column_name = column.respond_to?(:name) ? column.name.to_s : column.to_s
    column_caption = caption || (column.respond_to?(:caption) ? column.caption.to_s : column_name.humanize)

    current_key = query.sort_criteria.first&.first.to_s
    current_order = query.sort_criteria.first&.last.to_s
    next_order = (current_key == column_name && current_order == 'asc') ? 'desc' : 'asc'

    indicator =
      if current_key == column_name
        current_order == 'asc' ? ' ↑' : ' ↓'
      else
        ''
      end

    return "#{column_caption}#{indicator}" unless !column.respond_to?(:sortable?) || column.sortable?

    link_to(
      "#{column_caption}#{indicator}",
      ticket_journey_path(@project, query.as_params.merge(sort: "#{column_name}:#{next_order}"))
    )
  end

  def visible_native_query_columns(query)
    query.inline_columns.reject do |column|
      %w[id subject status].include?(column.name.to_s)
    end
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

  def group_summary(items)
    totals = items.map { |item| item[:durations][:TOTAL].to_f }.reject(&:zero?)

    {
      issues: items.size,
      avg_total: totals.any? ? (totals.sum / totals.size) : 0,
      max_total: totals.max || 0,
      returns: items.sum { |item| item[:durations][:C1] + item[:durations][:C2] + item[:durations][:C3] + item[:durations][:C4] }
    }
  end

  def peak_duration_field(durations)
    d_fields
      .map { |field| [field, durations[field[:key]].to_f] }
      .max_by { |field, value| [value, -d_fields.index(field)] }
  end

  def peak_duration_label(durations)
    field, value = peak_duration_field(durations)
    return '—' if field.nil? || value.to_f <= 0

    "#{field[:label]} #{format_hours(value)}"
  end

  def d_fields
    [
    { key: :D1,    label: 'D1',     aug: false, desc: 'Planning (New → To-Do)' },
    { key: :D2,    label: 'D2',     aug: false, desc: 'Wait for Dev (1st)' },
    { key: :D2aug, label: 'D2-aug', aug: true,  desc: 'Wait for Dev (returns)' },
    { key: :D3,    label: 'D3',     aug: false, desc: 'Under Development (1st)' },
    { key: :D3aug, label: 'D3-aug', aug: true,  desc: 'Under Dev (subsequent)' },
    { key: :D4,    label: 'D4',     aug: false, desc: 'QA Time (1st)' },
    { key: :D4aug, label: 'D4-aug', aug: true,  desc: 'QA Time (returns)' },
    { key: :D5,    label: 'D5',     aug: false, desc: 'Review → Ready to Merge' },
    { key: :D5aug, label: 'D5-aug', aug: true,  desc: 'Review → Returned' },
    { key: :D6,    label: 'D6',     aug: false, desc: 'Ready to Merge → Final Check' },
    { key: :D6aug, label: 'D6-aug', aug: true,  desc: 'Ready to Merge → Returned' },
    { key: :D7aug, label: 'D7-aug', aug: true,  desc: 'Final Check → Returned' },
    { key: :D7,    label: 'D7',     aug: false, desc: 'Final Check → Done/Closed' },
    { key: :D8,    label: 'D8',     aug: false, desc: 'Waiting for Validation (New → Feedback)' },
    { key: :D9,    label: 'D9',     aug: false, desc: 'Validation Time (Feedback → New)' },
    { key: :D10,   label: 'D10',    aug: false, desc: 'Not-Validation (Feedback → Archived)' },
  ]
  end

  def format_hours(h)
    return '—' if h.nil? || h == 0
    h = h.to_f
    total_minutes = (h * 60).round
    days    = total_minutes / (60 * 24)
    hours   = (total_minutes % (60 * 24)) / 60
    minutes = total_minutes % 60
    parts = []
    parts << "#{days}d"    if days > 0
    parts << "#{hours}h"   if hours > 0
    parts << "#{minutes}m" if minutes > 0 && days == 0
    parts.empty? ? '0m' : parts.join(' ')
  end

  def duration_css_class(h, aug: false)
    return 'tj-dur-zero' if h.nil? || h == 0
    base = aug ? 'tj-dur-aug' : 'tj-dur'
    base += ' tj-dur-high' if h.to_f > 48
    base
  end

  def counter_css_class(count)
    count.to_i > 0 ? 'tj-counter-active' : 'tj-counter-zero'
  end
end
