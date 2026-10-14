class PerformanceDashboardController < ApplicationController
  before_action :find_project
  before_action :authorize
  menu_item :performance_dashboard

  def index
    @metric = params[:metric].presence
    return render_404 if @metric && !TicketJourneyPerformance::DETAIL_LABELS.key?(@metric)
    @date = params[:as_of].present? ? Date.iso8601(params[:as_of]) : Date.current
    raise ArgumentError if @date > Date.current
    @settings = Setting.plugin_redmine_ticket_journey
    @start_date = configured_date(@settings['performance_start_date'])
    statuses = IssueStatus.all.index_by { |s| s.id.to_s }
    issues = Issue.visible(User.current).where(project_id: @project.id)
                  .joins(:tracker).where(trackers: { name: TicketJourneyPerformance::TRACKERS })
                  .includes(:tracker, :custom_values, journals: :details)
    # Respect field visibility as well as issue visibility. Hidden owner data must
    # not become available through dashboard filtering or aggregates.
    @detail_issues = {}
    rows = issues.filter_map do |issue|
      next unless issue.visible_custom_field_values.any? { |v| v.custom_field.id == 57 }
      @detail_issues[issue.id] = issue if @metric
      TicketJourneyPerformance.snapshot(issue, @date, statuses)
    end
    @owners = User.where(id: rows.map { |r| r[:owner_id] }.reject(&:blank?).uniq).order(:lastname, :firstname).to_a
    @owner = @owners.find { |u| u.id.to_s == params[:owner_id].to_s }
    @owner ||= @owners.find { |u| u.id == User.current.id } if params[:owner_id].blank?
    unless @owner
      return render_404 if @metric
      return
    end
    @report = TicketJourneyPerformance.calculate(rows.select { |r| r[:owner_id] == @owner.id.to_s }, @date, @start_date)
    @targets = %w[count weight].map { |kind| monthly_target(@settings["performance_#{kind}_field_id"]) }
    if @metric
      @detail_title = TicketJourneyPerformance::DETAIL_LABELS.fetch(@metric)
      @detail_rows = @report[:detail_sets].fetch(@metric).sort_by { |row| row[:id] }
      @detail_count = @detail_rows.size
      @detail_weight = TicketJourneyPerformance.weight(@detail_rows)
      @page_count = [(@detail_count / 100.0).ceil, 1].max
      @page = [[params[:page].to_i, 1].max, @page_count].min
      @detail_rows = @detail_rows.slice((@page - 1) * 100, 100) || []
      render :details
    end
  rescue ArgumentError
    render_error message: 'Choose a valid As of Date on or before today.', status: 422
  end

  private

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
