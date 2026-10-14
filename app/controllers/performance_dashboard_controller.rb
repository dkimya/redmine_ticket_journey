class PerformanceDashboardController < ApplicationController
  before_action :find_project
  before_action :authorize
  menu_item :performance_dashboard

  def index
    @metric = params[:metric].presence
    return render_404 if @metric && !TicketJourneyPerformance::DETAIL_LABELS.key?(@metric)
    @date = params[:as_of].present? ? Date.iso8601(params[:as_of]) : Date.current
    raise ArgumentError if @date > Date.current
    # Opening the menu must not scan issues or reconstruct journal history.
    # Project members seed the selector; calculated reports also discover former
    # owners from visible ticket history, retaining historical report links.
    if params[:owner_id].blank? && !@metric
      @owners = User.active.where(id: Member.where(project_id: performance_project_ids).select(:user_id))
                    .order(:lastname, :firstname).to_a
      @owner = @owners.find { |user| user.id == User.current.id }
      @initial_load = true
      return
    end
    @settings = Setting.plugin_redmine_ticket_journey
    @delivery_target = TicketJourney::PerformanceSettings.delivery_target(@settings)
    @start_date = configured_date(@settings['performance_start_date'])
    statuses = IssueStatus.all.index_by { |s| s.id.to_s }
    issues = Issue.visible(User.current).where(project_id: performance_project_ids)
                  .joins(:tracker).where(trackers: { name: TicketJourneyPerformance::TRACKERS })
                  .where('issues.created_on <= ?', @date.in_time_zone.end_of_day)
                  .select(Issue.column_names.reject { |name| name == 'description' }.map { |name| "issues.#{name}" })
                  .preload(:project, :tracker, :custom_values)
    # Respect field visibility as well as issue visibility. Hidden owner data must
    # not become available through dashboard filtering or aggregates.
    rows = []
    owner_ids = Set.new
    # Query caching otherwise retains the SQL results of every batch until the
    # request ends, defeating bounded issue/history loading on large projects.
    Issue.uncached do
      issues.find_in_batches(batch_size: TicketJourneyPerformance::BATCH_SIZE) do |batch|
        history = TicketJourneyPerformance.history_for(batch.map(&:id), @date)
        batch.each do |issue|
          visible_values = issue.visible_custom_field_values
          next unless visible_values.any? { |v| v.custom_field.id == 57 }
          row = TicketJourneyPerformance.snapshot(issue, @date, statuses,
            history: history.fetch(issue.id, []), visible_values: visible_values)
          next unless row
          owner_ids << row[:owner_id] if row[:owner_id].present?
          rows << row if row[:owner_id] == params[:owner_id].to_s
        end
      end
    end
    @owners = User.active.where(id: owner_ids.to_a).order(:lastname, :firstname).to_a
    # Active-only is a dropdown rule, not an access restriction. Resolve saved
    # links separately, but only for owners found on visible in-scope tickets.
    @owner = User.find_by(id: params[:owner_id]) if owner_ids.include?(params[:owner_id].to_s)
    @owner ||= @owners.find { |u| u.id == User.current.id } if params[:owner_id].blank?
    unless @owner
      return render_404 if @metric
      return
    end
    @report = TicketJourneyPerformance.calculate(rows, @date, @start_date)
    @targets = %w[count weight].map { |kind| monthly_target(@settings["performance_#{kind}_field_id"]) }
    if @metric
      @detail_title = TicketJourneyPerformance::DETAIL_LABELS.fetch(@metric)
      @detail_rows = @report[:detail_sets].fetch(@metric).sort_by { |row| row[:id] }
      @detail_count = @detail_rows.size
      @detail_weight = TicketJourneyPerformance.weight(@detail_rows)
      @page_count = [(@detail_count / 100.0).ceil, 1].max
      @page = [[params[:page].to_i, 1].max, @page_count].min
      @detail_rows = @detail_rows.slice((@page - 1) * 100, 100) || []
      @detail_issues = Issue.visible(User.current).where(project_id: performance_project_ids, id: @detail_rows.map { |row| row[:id] })
                            .includes(:project, :tracker).index_by(&:id)
      # A permission change during this request must not disclose a stale row.
      @detail_rows.select! { |row| @detail_issues.key?(row[:id]) }
      render :details
    end
  rescue ArgumentError
    render_error message: 'Choose a valid As of Date on or before today.', status: 422
  end

  private

  # Redmine's nested-set bounds include every depth, without recursively loading
  # project objects. Visibility and Issue.visible still apply independently.
  # A subquery avoids duplicate tickets/users belonging to multiple memberships.
  def performance_project_ids
    Project.visible(User.current).where('projects.lft >= ? AND projects.rgt <= ?', @project.lft, @project.rgt).select(:id)
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def configured_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def monthly_target(id)
    field = UserCustomField.find_by(id: id.to_i)
    return unless field && %w[int float].include?(field.field_format)
    # Do not disclose private user fields to dashboard viewers.
    return unless User.current.admin? || field.visible?
    value = Float(@owner.custom_value_for(field.id)&.value.to_s, exception: false)
    value if value && value.finite? && value.positive?
  end
end
