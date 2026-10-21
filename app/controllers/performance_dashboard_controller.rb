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
    @return_mode = @dashboard_type == 'live' && @performance_tab == 'returns'
    labels = @return_mode ? TicketJourneyPerformanceReturns::LABELS : TicketJourneyPerformance::DETAIL_LABELS
    return render_404 if @metric && !labels.key?(@metric)
    @date = params[:as_of].present? ? Date.iso8601(params[:as_of]) : Date.current
    raise ArgumentError if @date > Date.current
    requested_owners = Array(params[:owner_ids].presence || params[:owner_id]).map(&:to_s).reject(&:blank?).uniq
    requested_set = requested_owners.to_set
    if @dashboard_type == 'periodic' || @performance_tab == 'time'
      return render_404 unless requested_owners.all? { |id| id.match?(/\A[1-9]\d*\z/) }

      # Planned tabs retain context but must not run ticket/history/target scans.
      @owners = User.active.where(id: Member.where(project_id: performance_project_ids).select(:user_id))
                    .order(:lastname, :firstname).to_a
      @selected_owner_ids = requested_owners.presence || [@owners.find { |user| user.id == User.current.id }&.id].compact.map(&:to_s)
      return render :planned
    end
    # Opening the menu must not scan issues or reconstruct journal history.
    # Project members seed the selector; calculated reports also discover former
    # owners from visible ticket history, retaining historical report links.
    if requested_owners.empty? && !@metric
      @owners = User.active.where(id: Member.where(project_id: performance_project_ids).select(:user_id))
                    .order(:lastname, :firstname).to_a
      @owner = @owners.find { |user| user.id == User.current.id }
      @selected_owner_ids = [@owner&.id].compact.map(&:to_s)
      @initial_load = true
      return render(:returns) if @return_mode
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
    # Dropdown discovery rewinds ownership only; it never calculates status,
    # completion or started history for every developer's tickets.
    candidates = candidate_issues(issues, requested_owners)
    owner_ids = discover_owner_ids(@metric ? candidates : issues)
    issues = TicketJourneyPerformance.metric_scope(candidates, @metric, @date)
    # Respect field visibility as well as issue visibility. Hidden owner data must
    # not become available through dashboard filtering or aggregates.
    rows = []
    @return_trend = @return_mode && !@metric ? TicketJourneyPerformanceReturns.trend_points(@date) : nil
    @delivery_trend = !@return_mode && !@metric ? TicketJourneyPerformance.delivery_trend_points(@date) : nil
    trend_start = (@return_trend || @delivery_trend)&.first&.fetch(:date)
    @owner_change_rows = nil
    if !@return_mode && (!@metric || @metric == 'owner_changes')
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
            @delivery_trend.each do |point|
              historical_row = TicketJourneyPerformance.snapshot(issue, point[:date], statuses,
                history: history.fetch(issue.id, []), visible_values: visible_values,
                owner_value: visible_values.find { |value| value.custom_field.id == 57 }&.value.to_s)
              if historical_row && requested_set.include?(historical_row[:owner_id])
                TicketJourneyPerformance.add_delivery_trend_row!(point, historical_row)
              end
            end
          end
          trend_events = if @return_trend
            TicketJourneyPerformanceReturns.accumulate_trend!(@return_trend, issue,
              history.fetch(issue.id, []), statuses, @date, visible_values, requested_set)
          end
          row = TicketJourneyPerformance.snapshot(issue, @date, statuses,
            history: history.fetch(issue.id, []), visible_values: visible_values,
            owner_value: visible_values.find { |value| value.custom_field.id == 57 }&.value.to_s)
          next unless row
          if requested_set.include?(row[:owner_id])
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
    member_ids = Member.where(project_id: performance_project_ids).pluck(:user_id)
    @owners = User.active.where(id: (owner_ids.to_a + member_ids).uniq).order(:lastname, :firstname).to_a
    # Active-only is a dropdown rule, not an access restriction. Resolve saved
    # links separately, but only for owners found on visible in-scope tickets.
    allowed_ids = (@owners.map { |u| u.id.to_s } + owner_ids.to_a).to_set
    return render_404 unless requested_owners.all? { |id| allowed_ids.include?(id) }
    @selected_owners = User.where(id: requested_owners).order(:lastname, :firstname).to_a
    @selected_owner_ids = @selected_owners.map { |u| u.id.to_s }
    @owner_label = @selected_owners.map(&:name).join(', ')
    @owner = @selected_owners.first
    unless @owner
      return render_404 if @metric
      return
    end
    return render_returns(rows) if @return_mode
    return render_owner_changes if @metric == 'owner_changes'
    @report = TicketJourneyPerformance.calculate(rows, @date)
    ActiveRecord::Associations::Preloader.new(records: @selected_owners, associations: :custom_values).call unless @metric
    @target_details = @metric ? [] : %w[count weight].map do |kind|
      values = @selected_owners.map { |owner| monthly_target(@settings["performance_#{kind}_field_id"], owner) }
      {
        value: TicketJourneyPerformance.average_targets(values),
        missing_owners: @selected_owners.each_with_index.filter_map { |owner, index| owner.name if values[index].nil? }
      }
    end
    @targets = @target_details.map { |detail| detail[:value] }
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
    render_error message: 'Choose a valid As of Date on or before today.', status: 422
  end

  private

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
    @return_detail_sort = %w[id return_count repeat_count].include?(params[:sort]) ? params[:sort] : 'return_count'
    @direction = params[:direction] == 'asc' ? 'asc' : 'desc'
    @group_by = TicketJourneyPerformance::DETAIL_GROUPS.key?(params[:group_by]) ? params[:group_by] : nil
    names = @selected_owners.to_h { |owner| [owner.id.to_s, owner.name] }
    @detail_rows = @returns[:sets].fetch(@metric).map { |row| row.merge(owner_name: names[row[:owner_id]]) }
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
        changes = TicketJourneyPerformance.history_for(batch.map(&:id), @date, owner_only: true)
        field_values = TicketJourneyPerformance.batch_field_values(batch)
        batch.each do |issue|
          value = field_values.fetch(issue.id).find { |entry| entry.custom_field.id == 57 }
          next unless value
          owner = TicketJourneyPerformance.owner_at(issue, changes.fetch(issue.id, []), @date, owner_value: value.value.to_s)
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
