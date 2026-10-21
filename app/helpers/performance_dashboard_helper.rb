module PerformanceDashboardHelper
  def performance_consecutive_returns_definition
    'A consecutive return is counted when two successive qualifying return incidents come from the same stage (for example, Feedback → Returned twice adds 1). In Progress and other workflow steps between those incidents do not break the sequence. A return from a different stage breaks the sequence, but accumulated repeats are kept. Example: three returns from Feedback add 2, then two from Final Check add 1, giving 3 consecutive returns in total. Counts stop at the selected report date.'
  end

  def performance_return_params(overrides = {})
    performance_owner_params.merge(tab: 'returns', as_of: @date.iso8601).merge(overrides)
  end

  def performance_return_link(label, metric, ids = @selected_owner_ids)
    link_to label, performance_dashboard_path(@project, **performance_owner_params(ids), tab: 'returns', as_of: @date.iso8601, metric: metric)
  end

  def performance_return_heading(label, key)
    direction = @return_sort == key && @return_direction == 'asc' ? 'desc' : 'asc'
    marker = @return_sort == key ? (@return_direction == 'asc' ? ' ▲' : ' ▼') : ''
    link_to "#{label}#{marker}", performance_dashboard_path(@project, **performance_return_params(return_sort: key, return_direction: direction))
  end

  def performance_return_gradient(keys, report, denominator)
    return '#e7edf3' if denominator.zero?
    offset = 0.0
    stops = keys.each_with_index.map do |key, index|
      first = offset
      offset += report[:sets].fetch(key).size * 100.0 / denominator
      color = keys.size == 3 ? ['#00bc87', '#008fff', '#f65362'][index] : TicketJourneyPerformanceReturns::COLORS[index]
      "#{color} #{first}% #{offset}%"
    end
    "conic-gradient(#{stops.join(', ')})"
  end
  def performance_owner_params(ids = @selected_owner_ids)
    ids.size == 1 ? { owner_id: ids.first } : { owner_ids: ids }
  end

  def performance_comparison_link(value, metric, ids)
    link_to value, performance_dashboard_path(@project, **performance_owner_params(ids), as_of: @date.iso8601, metric: metric)
  end

  def performance_comparison_heading(label, key)
    direction = @comparison_sort == key && @comparison_direction == 'asc' ? 'desc' : 'asc'
    marker = @comparison_sort == key ? (@comparison_direction == 'asc' ? ' ▲' : ' ▼') : ''
    link_to "#{label}#{marker}", performance_dashboard_path(@project, **performance_owner_params,
      as_of: @date.iso8601, comparison_sort: key, comparison_direction: direction)
  end
  def performance_sort_heading(label, key)
    active = @sort == key
    next_direction = active && @direction == 'asc' ? 'desc' : 'asc'
    marker = active ? (@direction == 'asc' ? ' ▲' : ' ▼') : ''
    link_to "#{label}#{marker}", performance_dashboard_path(@project, **performance_detail_params(sort: key, direction: next_direction)),
      title: "Sort #{label} #{next_direction == 'asc' ? 'ascending' : 'descending'}#{@group_by ? ' within each selected group' : ' across all results'}"
  end

  def performance_detail_params(overrides = {})
    performance_owner_params.merge(as_of: @date.iso8601, metric: @metric, sort: @sort,
      direction: @direction, group_by: @group_by, detail_options: '1',
      detail_columns: @detail_columns).merge(overrides)
  end

  def performance_detail_cell(key, row, issue)
    case key
    when 'id' then link_to "##{issue.id}", issue_path(issue)
    when 'project' then link_to issue.project.name, project_path(issue.project)
    when 'subject' then issue.subject
    when 'tracker' then issue.tracker.name
    when 'priority' then issue.priority&.name || 'Not set'
    when 'estimate' then issue.estimated_hours.nil? ? 'Not set' : "#{number_with_precision(issue.estimated_hours, precision: 2)} h"
    when 'spent'
      if User.current.allowed_to?(:view_time_entries, issue.project)
        "#{number_with_precision(@detail_spent_hours.fetch(issue.id, 0), precision: 2)} h"
      else
        'Unavailable'
      end
    when 'owner' then row[:owner_name]
    when 'status' then row[:status_name].presence || 'Unknown'
    when 'due' then row[:due] ? format_date(row[:due]) : 'Not set'
    when 'weight' then row[:missing_weight] ? 'Unavailable' : performance_number(row[:weight])
    when 'completion' then row[:delivered_at] ? format_date(row[:delivered_at]) : 'Not recorded'
    end
  end

  def performance_detail_column_tip(key)
    {
      'subject' => 'The current ticket title is Redmine’s Subject field.',
      'priority' => 'Current ticket priority, not a historical priority snapshot.',
      'estimate' => 'Current Redmine Estimated time (PM estimate) in hours; not Ticket Owner Estimation.',
      'spent' => 'Lifetime visible time entries logged directly against this ticket, in hours. No child rollups or report-date cutoff. Restricted users may see partial totals; no time-view permission shows Unavailable.'
    }[key]
  end

  def performance_current_issues_path
    # Hand off the whole matching set, not just the current page. Native issue
    # visibility still applies; no historical owner/status filter is reapplied.
    issues_path(set_filter: '1', f: ['issue_id', 'status_id'],
      op: { issue_id: '=', status_id: '*' },
      v: { issue_id: [@matching_issue_ids.join(',')], status_id: [''] },
      c: ['id', 'project', 'subject', 'status', "cf_57", 'due_date', "cf_70"], group_by: '')
  end
  def performance_detail_link(label, metric)
    link_to label, performance_dashboard_path(@project, **performance_owner_params, as_of: @date.iso8601, metric: metric),
            title: "View tickets: #{TicketJourneyPerformance::DETAIL_LABELS.fetch(metric)}", class: 'performance-detail-link'
  end
  def performance_number(value)
    value.nil? ? 'N/A' : number_with_precision(value, precision: 1, strip_insignificant_zeros: true)
  end

  def performance_percent(numerator, denominator)
    denominator.positive? ? numerator.to_f * 100 / denominator : nil
  end

  def performance_tip(text)
    content_tag(:span, 'ⓘ', title: text, tabindex: 0, class: 'performance-tip', 'aria-label': text)
  end
end
