class PerformanceDashboardController < ApplicationController
  before_action :find_project
  before_action :authorize
  menu_item :performance_dashboard

  def index
    @dashboard_type = params[:dashboard_type].presence || 'live'
    return render_404 unless %w[live periodic].include?(@dashboard_type)
    @performance_tab = params[:tab].presence || 'tickets'
    return render_404 unless %w[tickets returns time].include?(@performance_tab)
    @metric = params[:metric].presence
    @periodic_tickets = @dashboard_type == 'periodic' && @performance_tab == 'tickets'
    @periodic_returns = @dashboard_type == 'periodic' && @performance_tab == 'returns'
    @periodic_time = @dashboard_type == 'periodic' && @performance_tab == 'time'
    @return_mode = @dashboard_type == 'live' && @performance_tab == 'returns'
    @time_mode = @dashboard_type == 'live' && @performance_tab == 'time'
    labels = if @periodic_tickets
      TicketJourneyPeriodicTickets::LABELS
    elsif @periodic_returns
      TicketJourneyPeriodicReturns::LABELS
    elsif @periodic_time
      TicketJourneyPeriodicTime::LABELS
    elsif @time_mode
      TicketJourneyPerformanceTime::LABELS
    else
      @return_mode ? TicketJourneyPerformanceReturns::LABELS : TicketJourneyPerformance::DETAIL_LABELS
    end
    return render_404 if @metric && !labels.key?(@metric) && (@dashboard_type == 'periodic' || @metric != 'owner_changes')
    @date = params[:as_of].present? ? Date.iso8601(params[:as_of]) : Date.current
    raise ArgumentError if @date > Date.current
    @time_month = nil
    if @time_mode && %w[time_delivered time_delivered_excluded].include?(@metric)
      @time_month = Date.iso8601(params[:time_month].to_s)
      return render_404 unless TicketJourneyPerformance.completed_month_ends(@date).include?(@time_month)
    end
    requested_owners = Array(params[:owner_ids].presence || params[:owner_id]).map(&:to_s).reject(&:blank?).uniq
    requested_set = requested_owners.to_set
    if @dashboard_type == 'periodic'
      return render_404 unless requested_owners.all? { |id| id.match?(/\A[1-9]\d*\z/) }

      @period_end = params[:red].present? ? Date.iso8601(params[:red]) : @date
      @period_start = params[:rsd].present? ? Date.iso8601(params[:rsd]) : @period_end.beginning_of_month
      raise ArgumentError if @period_start > @period_end || @period_end > Date.current

      # Initial Periodic navigation uses only the lightweight member selector.
      @owners = alphabetical_owners(User.active.where(id: Member.where(project_id: performance_project_ids).select(:user_id)))
      @selected_owner_ids = requested_owners.presence || [@owners.find { |user| user.id == User.current.id }&.id].compact.map(&:to_s)
      return render_periodic_tickets(requested_owners)
    end
    # Opening the menu must not scan issues or reconstruct journal history.
    # Project members seed the selector; calculated reports also discover former
    # owners from visible ticket history, retaining historical report links.
    if requested_owners.empty? && !@metric
      @owners = alphabetical_owners(User.active.where(id: Member.where(project_id: performance_project_ids).select(:user_id)))
      @owner = @owners.find { |user| user.id == User.current.id }
      @selected_owner_ids = [@owner&.id].compact.map(&:to_s)
      @initial_load = true
      return render(:returns) if @return_mode
      return render(:time) if @time_mode
      return
    end
    @settings = Setting.plugin_redmine_ticket_journey
    @delivery_target = TicketJourney::PerformanceSettings.delivery_target(@settings)
    statuses = IssueStatus.all.index_by { |s| s.id.to_s }
    issues = Issue.visible(User.current).where(project_id: performance_project_ids)
                  .joins(:tracker).where(trackers: { name: TicketJourneyPerformance::TRACKERS })
                  .where('issues.created_on <= ?', @date.in_time_zone.end_of_day)
                  .select(Issue.column_names.reject { |name| name == 'description' }.map { |name| "issues.#{name}" })
                  .preload(:project, :tracker)
    issues = issues.preload(:priority) if @time_mode
    # Current Ticket Owner governs attribution; history is retained for audit.
    candidates = candidate_issues(issues, requested_owners)
    owner_ids = discover_owner_ids(@metric ? candidates : issues)
    issues = TicketJourneyPerformance.metric_scope(candidates, @metric, @date)
    # Respect field visibility as well as issue visibility. Hidden owner data must
    # not become available through dashboard filtering or aggregates.
    rows = []
    @return_trend = @return_mode && !@metric ? TicketJourneyPerformanceReturns.trend_points(@date) : nil
    @delivery_trend = !@return_mode && !@time_mode && !@metric ? TicketJourneyPerformance.delivery_trend_points(@date) : nil
    @time_trend = @time_mode && !@metric ? TicketJourneyPerformanceTime.trend_points(@date) : nil
    @calendar = TicketJourney::WorkingCalendar.new(@settings) if @time_mode
    @time_owner_hours = {}
    @time_hours_fallback = Set.new
    @leaderboard_points = if !@time_mode && !@metric && requested_owners.size > 1
      requested_owners.to_h do |id|
        [id, @return_mode ? TicketJourneyPerformanceReturns.trend_points(@date) : TicketJourneyPerformance.delivery_trend_points(@date)]
      end
    end
    trend_start = (@return_trend || @delivery_trend)&.first&.fetch(:date)
    @owner_change_rows = nil
    if !@metric || @metric == 'owner_changes'
      trend_dates = TicketJourneyPerformance.completed_month_ends(@date)
      @owner_change_start, @owner_change_end = trend_dates.first.beginning_of_month, trend_dates.last
      @owner_change_rows = []
      # Include owner changes during the first plotted month as well.
      trend_start = @owner_change_start - 1
    end
    scanned = 0
    scan_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    # Query caching otherwise retains the SQL results of every batch until the
    # request ends, defeating bounded issue/history loading on large projects.
    Issue.uncached do
      issues.find_in_batches(batch_size: TicketJourneyPerformance::BATCH_SIZE) do |batch|
        # Earlier owner changes are necessary for exact month-end attribution.
        history = TicketJourneyPerformance.history_for(batch.map(&:id), trend_start || @date, include_return_reason: @return_mode)
        field_values = TicketJourneyPerformance.batch_field_values(batch, field_ids: @return_mode ? [57, 66, 70] : [57, 70])
        if @time_mode && @metric != 'owner_changes'
          time_entries = TicketJourneyPerformanceTime.hours_for(batch.map(&:id), @date)
          time_projects = batch.map(&:project).uniq(&:id).to_h { |project| [project.id, User.current.allowed_to?(:view_time_entries, project)] }
        end
        batch.each do |issue|
          scanned += 1
          visible_values = field_values.fetch(issue.id)
          next unless visible_values.any? { |v| v.custom_field.id == 57 }
          if @owner_change_rows
            changes = TicketJourneyPerformance.owner_changes_in(history.fetch(issue.id, []), @owner_change_start, @owner_change_end, requested_set)
            if changes.any?
              @owner_change_rows << { id: issue.id, subject: issue.subject, changes: changes }
            end
          end
          next if @metric == 'owner_changes'
          # Snapshot each month independently, including tickets since reassigned
          # away from a selected owner. Only aggregate totals survive the batch.
          if @delivery_trend
            @delivery_trend.each_with_index do |point, point_index|
              historical_row = TicketJourneyPerformance.snapshot(issue, point[:date], statuses,
                history: history.fetch(issue.id, []), visible_values: visible_values,
                owner_value: visible_values.find { |value| value.custom_field.id == 57 }&.value.to_s)
              if historical_row && requested_set.include?(historical_row[:owner_id])
                TicketJourneyPerformance.add_delivery_trend_row!(point, historical_row)
                if @leaderboard_points
                  owner_point = @leaderboard_points.fetch(historical_row[:owner_id])[point_index]
                  TicketJourneyPerformance.add_delivery_trend_row!(owner_point, historical_row)
                end
              end
            end
          end
          trend_events = if @return_trend
            TicketJourneyPerformanceReturns.accumulate_trend!(@return_trend, issue,
              history.fetch(issue.id, []), statuses, @date, visible_values, requested_set, owner_points: @leaderboard_points)
          end
          if @time_trend
            @time_trend.each do |point|
              snapshot = TicketJourneyPerformance.snapshot(issue, point[:date], statuses,
                history: history.fetch(issue.id, []), visible_values: visible_values,
                owner_value: visible_values.find { |value| value.custom_field.id == 57 }&.value.to_s)
              next unless snapshot && requested_set.include?(snapshot[:owner_id])
              hours = time_projects[issue.project_id] ? TicketJourneyPerformanceTime.spent(time_entries[issue.id], point[:date]) : nil
              TicketJourneyPerformanceTime.add_productivity!(point, snapshot, hours)
            end
          end
          snapshot_date = @time_month || @date
          row = TicketJourneyPerformance.snapshot(issue, snapshot_date, statuses,
            history: history.fetch(issue.id, []), visible_values: visible_values,
            owner_value: visible_values.find { |value| value.custom_field.id == 57 }&.value.to_s)
          next unless row
          if requested_set.include?(row[:owner_id])
            if @time_mode
              row = TicketJourneyPerformanceTime.enrich(row, issue, snapshot_date, @calendar, time_entries[issue.id],
                time_projects[issue.project_id], time_daily_hours(row[:owner_id]))
              if @time_month
                reasons = []
                reasons << 'Set a positive visible Complexity Weight' if row[:missing_weight]
                reasons << 'Logged time unavailable under current permissions' if row[:spent].nil?
                reasons << 'No recorded completion date; inspect status history' unless row[:delivered_at]
                row = row.merge(exclusions: reasons)
              end
            end
            if @return_mode
              next unless TicketJourneyPerformanceReturns.eligible?(row)
              reason = visible_values.find { |value| value.custom_field.id == 66 }
              events = trend_events || TicketJourneyPerformanceReturns.events_for(issue, history.fetch(issue.id, []), statuses, @date,
                reason_value: reason&.value, reason_visible: !reason.nil?)
              row = row.merge(events: events, return_count: events.size, repeat_count: events.count { |event| event[:repeat] })
            end
            # Only compact sorting metadata survives the batch, not Issue objects.
            row = row.merge(project_id: issue.project_id, project_name: issue.project.name,
                            subject: issue.subject, tracker_name: issue.tracker.name) if @metric
            rows << row
          end
        end
      end
    end
    Rails.logger.info("Performance candidate scan: #{scanned} tickets, #{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - scan_started).round(3)}s")
    TicketJourneyPerformanceReturns.finish_trend!(@return_trend) if @return_trend
    TicketJourneyPerformance.finish_delivery_trend!(@delivery_trend) if @delivery_trend
    TicketJourneyPerformanceTime.finish_trend!(@time_trend) if @time_trend
    member_ids = Member.where(project_id: performance_project_ids).pluck(:user_id)
    @owners = alphabetical_owners(User.active.where(id: (owner_ids.to_a + member_ids).uniq))
    # Active-only is a dropdown rule, not an access restriction. Resolve saved
    # links separately, but only for owners found on visible in-scope tickets.
    allowed_ids = (@owners.map { |u| u.id.to_s } + owner_ids.to_a).to_set
    return render_404 unless requested_owners.all? { |id| allowed_ids.include?(id) }
    @selected_owners = alphabetical_owners(User.where(id: requested_owners))
    @selected_owner_ids = @selected_owners.map { |u| u.id.to_s }
    @owner_label = @selected_owners.map(&:name).join(', ')
    @owner = @selected_owners.first
    unless @owner
      return render_404 if @metric
      return
    end
    @leaderboard_entries = if @leaderboard_points
      @selected_owners.map do |owner|
        points = @leaderboard_points.fetch(owner.id.to_s)
        TicketJourneyPerformanceReturns.finish_trend!(points) if @return_mode
        { owner: owner, points: points }
      end
    end
    return render_owner_changes if @metric == 'owner_changes'
    return render_returns(rows) if @return_mode
    return render_time(rows) if @time_mode
    @report = TicketJourneyPerformance.calculate(rows, @date)
    ActiveRecord::Associations::Preloader.new(records: @selected_owners, associations: :custom_values).call unless @metric
    @target_details = @metric ? [] : %w[count weight].map do |kind|
      values = @selected_owners.map { |owner| monthly_target(@settings["performance_#{kind}_field_id"], owner) }
      {
        value: TicketJourneyPerformance.average_targets(values),
        owner_values: @selected_owners.each_with_index.to_h { |owner, index| [owner.id.to_s, values[index]] },
        missing_owners: @selected_owners.each_with_index.filter_map { |owner, index| owner.name if values[index].nil? }
      }
    end
    @targets = @target_details.map { |detail| detail[:value] }
    if @leaderboard_entries
      @leaderboard_entries.each { |entry| entry[:target] = @target_details[1][:owner_values][entry[:owner].id.to_s] }
    end
    TicketJourneyPerformance.finish_output_trend!(@delivery_trend, @selected_owners.size) if @delivery_trend
    @comparison = @metric ? [] : @selected_owners.map do |owner|
      { owner: owner, report: TicketJourneyPerformance.calculate(rows.select { |r| r[:owner_id] == owner.id.to_s }, @date) }
    end
    @comparison_sort = %w[owner open not_overdue started untouched open_weight not_overdue_weight started_weight untouched_weight stopped due_soon].include?(params[:comparison_sort]) ? params[:comparison_sort] : 'owner'
    @comparison_direction = params[:comparison_direction] == 'desc' ? 'desc' : 'asc'
    @comparison.sort_by! do |entry|
      key = @comparison_sort
      index = %w[open not_overdue started untouched].index(key.sub(/_weight\z/, ''))
      value = if key == 'owner'
                entry[:owner].name.downcase
              elsif index
                group = entry[:report][:groups][index]
                key.end_with?('_weight') ? TicketJourneyPerformance.weight(group) : group.size
              else
                entry[:report][key.to_sym]
              end
      [value, entry[:owner].id]
    end
    @comparison.reverse! if @comparison_direction == 'desc'
    if @selected_owners.size > 1
      # Compare mean monthly output per owner with mean monthly target per owner.
      # Keep zero-delivery owners in this denominator and retain contributor sets.
      @report[:monthly_count] /= @selected_owners.size.to_f
      @report[:monthly_weight] /= @selected_owners.size.to_f
    end
    if @metric
      @detail_title = TicketJourneyPerformance::DETAIL_LABELS.fetch(@metric)
      @group_by = TicketJourneyPerformance::DETAIL_GROUPS.key?(params[:group_by]) ? params[:group_by] : nil
      requested_columns = params[:detail_options] == '1' ? Array(params[:detail_columns]).map(&:to_s) : TicketJourneyPerformance::DEFAULT_DETAIL_COLUMNS
      @detail_columns = ['id'] + (TicketJourneyPerformance::DETAIL_COLUMNS.keys - ['id']).select { |key| requested_columns.include?(key) }
      @sort, @direction = TicketJourneyPerformance.detail_sort_options(@metric, params[:sort], params[:direction])
      owner_names = @selected_owners.to_h { |owner| [owner.id.to_s, owner.name] }
      detail_set = @report[:detail_sets].fetch(@metric).map { |row| row.merge(owner_name: owner_names[row[:owner_id]] || 'Unknown') }
      @detail_rows = TicketJourneyPerformance.sort_details(detail_set, @sort, @direction, group_by: @group_by)
      @matching_issue_ids = @detail_rows.map { |row| row[:id] }.uniq
      @group_totals = @detail_rows.group_by { |row| TicketJourneyPerformance.detail_group_key(row, @group_by) }.transform_values do |group|
        { count: group.size, weight: TicketJourneyPerformance.weight(group) }
      end
      @detail_count = @detail_rows.size
      @detail_weight = TicketJourneyPerformance.weight(@detail_rows)
      @page_count = [(@detail_count / 100.0).ceil, 1].max
      @page = [[params[:page].to_i, 1].max, @page_count].min
      @detail_rows = @detail_rows.slice((@page - 1) * 100, 100) || []
      @detail_issues = Issue.visible(User.current).where(project_id: performance_project_ids, id: @detail_rows.map { |row| row[:id] })
                            .includes(:project, :tracker, :priority).index_by(&:id)
      # A permission change during this request must not disclose a stale row.
      @detail_rows.select! { |row| @detail_issues.key?(row[:id]) }
      # One page-sized aggregate, only when selected. No child rollups or dates
      # inferred from the historical report; native time visibility is enforced.
      @detail_spent_hours = if @detail_columns.include?('spent')
        TimeEntry.visible(User.current).where(issue_id: @detail_issues.keys).group(:issue_id).sum(:hours)
      else
        {}
      end
      render :details
    end
  rescue ArgumentError
    message = if @dashboard_type == 'periodic'
      'Choose valid report dates: RSD must be on or before RED, and RED must be on or before today.'
    else
      'Choose a valid As of Date on or before today.'
    end
    render_error message: message, status: 422
  end

  private

  def render_periodic_tickets(requested_owners)
    page = @periodic_time ? :periodic_time : (@periodic_returns ? :periodic_returns : :periodic_tickets)
    return render(page) if requested_owners.empty? && !@metric
    return render_404 if requested_owners.empty?

    if @periodic_time
      @settings = Setting.plugin_redmine_ticket_journey
      @calendar = TicketJourney::WorkingCalendar.new(@settings)
      @time_owner_hours, @time_hours_fallback = {}, Set.new
      @periodic_project_time_permissions = periodic_time_project_permissions
      allowed = @periodic_project_time_permissions.values
      @periodic_time_available, @periodic_time_any_available = allowed.all?, allowed.any?
      @time_bucket = params[:time_bucket].present? ? Date.iso8601(params[:time_bucket]) : nil
      return render_404 if @time_bucket && (!@metric || !TicketJourneyPeriodicReturns.intervals(@period_start, @period_end).map(&:last).include?(@time_bucket))
    end

    @trend_date = if @metric&.start_with?('trend_')
      Date.iso8601(params[:trend_date].to_s)
    end
    valid_dates = if @periodic_returns
      TicketJourneyPeriodicReturns.intervals(@period_start, @period_end).map(&:last)
    else
      TicketJourneyPeriodicTickets.trend_dates(@period_start, @period_end)
    end
    if @trend_date && !valid_dates.include?(@trend_date)
      return render_404
    end
    selected = requested_owners.to_set
    statuses = IssueStatus.all.index_by { |status| status.id.to_s }
    scope = Issue.visible(User.current).where(project_id: performance_project_ids)
      .joins(:tracker).where(trackers: { name: TicketJourneyPerformance::TRACKERS })
      .where('issues.created_on <= ?', @period_end.in_time_zone.end_of_day)
      .select(Issue.column_names.reject { |name| name == 'description' }.map { |name| "issues.#{name}" })
      .preload(:project, :tracker, :priority)
    rows = []
    discovered = Set.new
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Issue.uncached do
      scope.find_in_batches(batch_size: TicketJourneyPerformance::BATCH_SIZE) do |batch|
        values = TicketJourneyPerformance.batch_field_values(batch, field_ids: @periodic_returns ? [57, 66, 70] : [57, 70])
        hours = TicketJourneyPeriodicTime.load_hours(batch.map(&:id), @period_start, @period_end, requested_owners) if @periodic_time
        selected_batch = batch.select do |issue|
          owner = values.fetch(issue.id).find { |value| value.custom_field.id == 57 }&.value.to_s
          discovered << owner if owner.present?
          booked = @periodic_time && (hours[:logs].key?(issue.id) || hours[:invalid_logs].keys.any? { |id, _user, _day| id == issue.id })
          if booked
            hours[:logs].fetch(issue.id, {}).each_key { |user| discovered << user }
            hours[:invalid_logs].each_key { |id, user, _day| discovered << user.to_s if id == issue.id }
          end
          selected.include?(owner) || booked
        end
        next if selected_batch.empty?

        history = if @periodic_returns
          TicketJourneyPeriodicTickets.history_for(selected_batch.map(&:id), @period_end, include_return_reason: true)
        else
          TicketJourneyPeriodicTickets.history_for(selected_batch.map(&:id), @period_end)
        end
        selected_batch.each do |issue|
          owner_value = values.fetch(issue.id).find { |value| value.custom_field.id == 57 }
          owner = owner_value&.value.to_s
          row = TicketJourneyPeriodicTickets.row(issue, @period_start, @period_end, statuses,
            history.fetch(issue.id, []), values.fetch(issue.id), owner)
          if @periodic_time && row
            row = TicketJourneyPeriodicTime.enrich(row, issue, hours,
              @periodic_project_time_permissions.fetch(issue.project_id, false), !owner_value.nil?)
          end
          if @periodic_returns && row && TicketJourneyPeriodicTickets.delivered?(row, @period_start, @period_end) &&
              !TicketJourneyPeriodicTickets.excluded?(row)
            row = TicketJourneyPeriodicReturns.enrich(row, issue, history.fetch(issue.id, []), statuses, @period_end, values.fetch(issue.id))
          end
          rows << row if row
        end
      end
    end
    Rails.logger.info("Periodic #{@performance_tab.titleize} scan: #{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3)}s")
    member_ids = @owners.map { |owner| owner.id.to_s }
    return render_404 unless requested_owners.all? { |id| discovered.include?(id) || member_ids.include?(id) }

    @owners = alphabetical_owners(User.active.where(id: (member_ids + discovered.to_a).uniq))
    @selected_owners = alphabetical_owners(User.where(id: requested_owners))
    return render_404 unless @selected_owners.size == requested_owners.size

    @selected_owner_ids = @selected_owners.map { |owner| owner.id.to_s }
    @owner_label = @selected_owners.map(&:name).join(', ')
    return render_periodic_time(rows) if @periodic_time
    @periodic_report = TicketJourneyPeriodicTickets.calculate(rows, @period_start, @period_end, with_trends: !@periodic_returns)
    return render_periodic_returns(rows) if @periodic_returns
    unless @metric
      @periodic_owners = @selected_owners.map do |owner|
        { owner: owner, report: TicketJourneyPeriodicTickets.calculate(rows.select { |row| row[:owner_id] == owner.id.to_s }, @period_start, @period_end) }
      end
      return render :periodic_tickets
    end
    @detail_title = TicketJourneyPeriodicTickets::LABELS.fetch(@metric)
    records = if @trend_date
      TicketJourneyPeriodicTickets.trend_rows(@periodic_report[:sets], @metric.delete_prefix('trend_'), @trend_date)
    else
      @periodic_report[:sets].fetch(@metric)
    end
    @sort, @direction = TicketJourneyPerformance.detail_sort_options(@metric, params[:sort], params[:direction])
    @group_by = TicketJourneyPerformance::DETAIL_GROUPS.key?(params[:group_by]) ? params[:group_by] : nil
    names = @selected_owners.to_h { |owner| [owner.id.to_s, owner.name] }
    records = records.map { |row| row.merge(owner_name: names[row[:owner_id]]) }
    @detail_rows = TicketJourneyPerformance.sort_details(records, @sort, @direction, group_by: @group_by)
    @matching_issue_ids = @detail_rows.map { |row| row[:id] }
    @detail_count = @detail_rows.size
    @detail_weight = TicketJourneyPerformance.weight(@detail_rows)
    @group_totals = @detail_rows.group_by { |row| TicketJourneyPerformance.detail_group_key(row, @group_by) }
      .transform_values { |group| TicketJourneyPeriodicTickets.summary(group) }
    @page_count = [(@detail_count / 100.0).ceil, 1].max
    @page = [[params[:page].to_i, 1].max, @page_count].min
    @detail_rows = @detail_rows.slice((@page - 1) * 100, 100) || []
    @detail_issues = Issue.visible(User.current).where(project_id: performance_project_ids, id: @detail_rows.map { |row| row[:id] })
      .includes(:project, :tracker, :priority).index_by(&:id)
    @detail_rows.select! { |row| @detail_issues.key?(row[:id]) }
    render :periodic_details
  end

  def render_periodic_time(rows)
    build = lambda do |first, last, packages = nil|
      @selected_owners.map do |owner|
        id = owner.id.to_s
        report = TicketJourneyPeriodicTime.owner_report(rows, id, first, last, @calendar, @settings, time_daily_hours(id),
          total_available: @periodic_time_available, any_time_available: @periodic_time_any_available,
          package: packages && packages[id], completion_range: packages ? [first, last] : nil,
          comparison_range: [@period_start, @period_end])
        { owner: owner, report: report }
      end
    end
    @periodic_time_owners = build.call(@period_start, @period_end)
    @periodic_time_report = TicketJourneyPeriodicTime.aggregate(@periodic_time_owners.map { |entry| entry[:report] }, @settings)
    @periodic_time_completion = %w[expected completed other debt].to_h do |key|
      summaries = @periodic_time_owners.map { |entry| entry[:report][:tickets][:summaries][key] }
      [key, { count: summaries.sum { |summary| summary[:count] }, weight: summaries.sum { |summary| summary[:weight] } }]
    end
    packages = @periodic_time_owners.to_h { |entry| [entry[:owner].id.to_s, entry[:report][:tickets]] }
    @estimate_allowance = TicketJourney::PerformanceSettings.time_threshold(@settings, 'performance_estimate_allowance')
    if @metric
      entries = @periodic_time_owners
      @time_detail_start, @time_detail_end = @period_start, @period_end
      if @time_bucket
        first, last = TicketJourneyPeriodicReturns.intervals(@period_start, @period_end).find { |_start, finish| finish == @time_bucket }
        @time_detail_start, @time_detail_end = first, last
        entries = build.call(first, last, packages)
      end
      @detail_title = TicketJourneyPeriodicTime::LABELS.fetch(@metric)
      records = entries.flat_map do |entry|
        entry[:report][:sets].fetch(@metric).map { |row| row.merge(report_owner_id: entry[:owner].id.to_s, report_owner_name: entry[:owner].name) }
      end
      @time_sort = %w[id actor].include?(params[:sort]) ? params[:sort] : 'id'
      @direction = params[:direction] == 'desc' ? 'desc' : 'asc'
      @time_group = TicketJourneyPeriodicTime::GROUP_FIELDS.key?(params[:time_group]) ? params[:time_group] : nil
      records.sort! do |left, right|
        group = TicketJourneyPeriodicTime.group_value(left, @time_group).downcase <=> TicketJourneyPeriodicTime.group_value(right, @time_group).downcase
        next group unless group.zero?
        a = @time_sort == 'actor' ? [left[:report_owner_name].downcase, left[:id]] : [left[:id], left[:report_owner_id].to_i]
        b = @time_sort == 'actor' ? [right[:report_owner_name].downcase, right[:id]] : [right[:id], right[:report_owner_id].to_i]
        (a <=> b) * (@direction == 'desc' ? -1 : 1)
      end
      @time_group_totals = records.group_by { |row| TicketJourneyPeriodicTime.group_value(row, @time_group) }.transform_values(&:size)
      @detail_count = records.size
      @matching_issue_ids = records.map { |row| row[:id] }.uniq
      @page_count = [(@detail_count / 100.0).ceil, 1].max
      @page = [[params[:page].to_i, 1].max, @page_count].min
      @detail_rows = records.slice((@page - 1) * 100, 100) || []
      @detail_issues = Issue.visible(User.current).where(project_id: performance_project_ids, id: @detail_rows.map { |row| row[:id] }).includes(:project, :tracker).index_by(&:id)
      @detail_rows.select! { |row| @detail_issues.key?(row[:id]) }
      owner_ids = @detail_rows.select { |row| row[:owner_visible] }.map { |row| row[:owner_id] }.reject(&:blank?).uniq
      @current_owner_names = User.where(id: owner_ids).to_h { |user| [user.id.to_s, user.name] }
      return render :periodic_time_details
    end
    @periodic_time_trends = TicketJourneyPeriodicReturns.intervals(@period_start, @period_end).map do |first, last|
      entries = build.call(first, last, packages)
      { start: first, date: last, owners: entries, report: TicketJourneyPeriodicTime.aggregate(entries.map { |entry| entry[:report] }, @settings) }
    end
    render :periodic_time
  end

  def periodic_time_project_permissions
    Project.where(id: performance_project_ids).to_h { |project| [project.id, User.current.allowed_to?(:view_time_entries, project)] }
  end

  def render_periodic_returns(rows)
    @periodic_return_report = TicketJourneyPeriodicReturns.calculate(@periodic_report, @period_start, @period_end)
    @returns = @periodic_return_report[:expected]
    unless @metric
      @periodic_return_owners = @selected_owners.map do |owner|
        tickets = TicketJourneyPeriodicTickets.calculate(rows.select { |row| row[:owner_id] == owner.id.to_s },
          @period_start, @period_end, with_trends: false)
        { owner: owner, report: TicketJourneyPeriodicReturns.calculate(tickets, @period_start, @period_end) }
      end
      return render :periodic_returns
    end
    @detail_title = TicketJourneyPeriodicReturns::LABELS.fetch(@metric)
    records = if @trend_date
      interval = TicketJourneyPeriodicReturns.intervals(@period_start, @period_end).find { |_first, last| last == @trend_date }
      cohort = TicketJourneyPeriodicReturns.cohort_rows(@periodic_return_report[:sets]['returns_open'], *interval)
      @metric == 'trend_returned' ? cohort.select { |row| row[:return_count].positive? } : cohort
    else
      @periodic_return_report[:sets].fetch(@metric)
    end
    render_return_details(records)
  end

  def time_daily_hours(owner_id)
    return @time_owner_hours[owner_id] if @time_owner_hours.key?(owner_id)
    id = @settings['performance_weekly_hours_field_id'].to_s
    @time_weekly_field ||= UserCustomField.find_by(id: id.to_i, field_format: %w[int float]) if id.present?
    field = @time_weekly_field
    value = if field && (User.current.admin? || field.visible?)
      TicketJourneyPerformanceTime.positive(User.find_by(id: owner_id)&.custom_value_for(field.id)&.value)
    end
    daily = value / @calendar.weekdays.size if value
    if daily.nil? || daily > 24
      @time_hours_fallback << owner_id if id.present?
      daily = @calendar.hours_per_day
    end
    @time_owner_hours[owner_id] = daily
  end

  def render_time(rows)
    @time_report = TicketJourneyPerformanceTime.calculate(rows, month: @time_month)
    @estimate_allowance = TicketJourney::PerformanceSettings.time_threshold(@settings, 'performance_estimate_allowance')
    @sv_warning = TicketJourney::PerformanceSettings.time_threshold(@settings, 'performance_sv_warning')
    unless @metric
      @time_comparison = @selected_owners.map do |owner|
        { owner: owner, report: TicketJourneyPerformanceTime.calculate(rows.select { |row| row[:owner_id] == owner.id.to_s }) }
      end
      @time_sort = %w[owner open estimate spent sv].include?(params[:time_sort]) ? params[:time_sort] : 'owner'
      @time_direction = params[:time_direction] == 'desc' ? 'desc' : 'asc'
      @time_comparison.sort! do |a, b|
        x = @time_sort == 'owner' ? a[:owner].name.downcase : a[:report][@time_sort.to_sym]
        y = @time_sort == 'owner' ? b[:owner].name.downcase : b[:report][@time_sort.to_sym]
        result = if x.nil? || y.nil?
          (x.nil? ? 1 : 0) <=> (y.nil? ? 1 : 0)
        else
          (x <=> y) * (@time_direction == 'desc' ? -1 : 1)
        end
        result.zero? ? a[:owner].id <=> b[:owner].id : result
      end
      return render(:time)
    end

    @detail_title = TicketJourneyPerformanceTime::LABELS.fetch(@metric)
    @group_by = TicketJourneyPerformance::DETAIL_GROUPS.key?(params[:group_by]) ? params[:group_by] : nil
    @sort = %w[id age due spent].include?(params[:sort]) ? params[:sort] : 'id'
    @direction = params[:direction] == 'desc' ? 'desc' : 'asc'
    names = @selected_owners.to_h { |owner| [owner.id.to_s, owner.name] }
    records = @time_report[:sets].fetch(@metric).map { |row| row.merge(owner_name: names[row[:owner_id]]) }
    records.sort! do |a, b|
      group = TicketJourneyPerformance.detail_group_key(a, @group_by) <=> TicketJourneyPerformance.detail_group_key(b, @group_by) if @group_by
      next group if group && !group.zero?
      x, y = a[@sort.to_sym], b[@sort.to_sym]
      result = if x.nil? || y.nil?
        (x.nil? ? 1 : 0) <=> (y.nil? ? 1 : 0)
      else
        (x <=> y) * (@direction == 'desc' ? -1 : 1)
      end
      result.zero? ? a[:id] <=> b[:id] : result
    end
    @detail_count = records.size
    @matching_issue_ids = records.map { |row| row[:id] }
    @page_count = [(@detail_count / 100.0).ceil, 1].max
    @page = [[params[:page].to_i, 1].max, @page_count].min
    @detail_rows = records.slice((@page - 1) * 100, 100) || []
    @detail_issues = Issue.visible(User.current).where(project_id: performance_project_ids, id: @detail_rows.map { |row| row[:id] })
      .includes(:project, :tracker).index_by(&:id)
    @detail_rows.select! { |row| @detail_issues.key?(row[:id]) }
    render :time_details
  end

  def alphabetical_owners(users)
    users.to_a.sort_by { |user| [user.name.to_s.downcase, user.id] }
  end

  def render_owner_changes
    @owner_change_rows.sort_by! { |row| [-row[:changes].map { |change| change[:at].to_f }.max, row[:id]] }
    @detail_count = @owner_change_rows.size
    @page_count = [(@detail_count / 100.0).ceil, 1].max
    @page = [[params[:page].to_i, 1].max, @page_count].min
    @owner_change_rows = @owner_change_rows.slice((@page - 1) * 100, 100) || []
    visible_ids = Issue.visible(User.current).where(project_id: performance_project_ids, id: @owner_change_rows.map { |row| row[:id] }).pluck(:id).to_set
    @owner_change_rows.select! { |row| visible_ids.include?(row[:id]) }
    user_ids = @owner_change_rows.flat_map { |row| row[:changes].flat_map { |change| [change[:old_id], change[:new_id]] } }.reject(&:blank?).uniq
    @change_owner_names = User.where(id: user_ids).to_h { |user| [user.id.to_s, user.name] }
    render :owner_changes
  end

  def render_returns(rows)
    @returns = TicketJourneyPerformanceReturns.calculate(rows)
    @return_comparison = @selected_owners.map do |owner|
      { owner: owner, report: TicketJourneyPerformanceReturns.calculate(rows.select { |row| row[:owner_id] == owner.id.to_s }) }
    end
    allowed = %w[owner open incidents with_repeats repeats ratio adjusted_ratio]
    @return_sort = allowed.include?(params[:return_sort]) ? params[:return_sort] : 'owner'
    @return_direction = params[:return_direction] == 'desc' ? 'desc' : 'asc'
    @return_comparison.sort! do |a, b|
      x = @return_sort == 'owner' ? a[:owner].name.downcase : a[:report][@return_sort.to_sym]
      y = @return_sort == 'owner' ? b[:owner].name.downcase : b[:report][@return_sort.to_sym]
      if x.nil? || y.nil?
        (x.nil? ? 1 : 0) <=> (y.nil? ? 1 : 0)
      else
        comparison = (x <=> y) * (@return_direction == 'desc' ? -1 : 1)
        comparison.zero? ? a[:owner].id <=> b[:owner].id : comparison
      end
    end
    return render(:returns) unless @metric

    @detail_title = TicketJourneyPerformanceReturns::LABELS.fetch(@metric)
    render_return_details(@returns[:sets].fetch(@metric))
  end

  def render_return_details(records)
    @return_detail_sort = %w[id return_count repeat_count].include?(params[:sort]) ? params[:sort] : 'return_count'
    @direction = params[:direction] == 'asc' ? 'asc' : 'desc'
    @group_by = TicketJourneyPerformance::DETAIL_GROUPS.key?(params[:group_by]) ? params[:group_by] : nil
    names = @selected_owners.to_h { |owner| [owner.id.to_s, owner.name] }
    @detail_rows = records.map { |row| row.merge(owner_name: names[row[:owner_id]]) }
    @detail_rows.sort_by! { |row| [row[@return_detail_sort.to_sym] * (@direction == 'asc' ? 1 : -1), row[:id]] }
    if @group_by
      @detail_rows = @detail_rows.each_with_index.sort_by { |row, index| [TicketJourneyPerformance.detail_group_key(row, @group_by), index] }.map(&:first)
    end
    @detail_count = @detail_rows.size
    @page_count = [(@detail_count / 100.0).ceil, 1].max
    @page = [[params[:page].to_i, 1].max, @page_count].min
    @matching_issue_ids = @detail_rows.map { |row| row[:id] }
    @detail_rows = @detail_rows.slice((@page - 1) * 100, 100) || []
    @detail_issues = Issue.visible(User.current).where(project_id: performance_project_ids, id: @detail_rows.map { |row| row[:id] }).includes(:project, :tracker).index_by(&:id)
    @detail_rows.select! { |row| @detail_issues.key?(row[:id]) }
    render :return_details
  end

  def candidate_issues(scope, owner_ids)
    TicketJourneyPerformance.candidate_scope(scope, owner_ids)
  end

  def discover_owner_ids(scope)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    owners = Set.new
    Issue.uncached do
      scope.find_in_batches(batch_size: TicketJourneyPerformance::BATCH_SIZE) do |batch|
        field_values = TicketJourneyPerformance.batch_field_values(batch)
        batch.each do |issue|
          value = field_values.fetch(issue.id).find { |entry| entry.custom_field.id == 57 }
          next unless value
          owner = TicketJourneyPerformance.owner_at(issue, [], @date, owner_value: value.value.to_s)
          owners << owner if owner.present?
        end
      end
    end
    Rails.logger.info("Performance owner discovery: #{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3)}s")
    owners
  end

  # Redmine's nested-set bounds include every depth, without recursively loading
  # project objects. Visibility and Issue.visible still apply independently.
  # A subquery avoids duplicate tickets/users belonging to multiple memberships.
  def performance_project_ids
    Project.visible(User.current).where('projects.lft >= ? AND projects.rgt <= ?', @project.lft, @project.rgt).select(:id)
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def monthly_target(id, owner = @owner)
    fields = (@monthly_target_fields ||= {})
    field = fields.fetch(id.to_i) { fields[id.to_i] = UserCustomField.find_by(id: id.to_i) }
    return unless field && %w[int float].include?(field.field_format)
    # Do not disclose private user fields to dashboard viewers.
    return unless User.current.admin? || field.visible?
    value = Float(owner.custom_value_for(field.id)&.value.to_s, exception: false)
    value if value && value.finite? && value.positive?
  end
end
