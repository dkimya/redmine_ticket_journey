require_relative 'lib/ticket_journey/return_count'
require_relative 'lib/ticket_journey/issue_patch'
require_relative 'lib/ticket_journey/issue_query_patch'
require_relative 'lib/ticket_journey/hooks'

# Redmine's plugin loader already runs init.rb inside its to_prepare callback.
# Apply patches here so they are available on the first boot and after reloads.
Issue.prepend TicketJourney::IssuePatch unless Issue < TicketJourney::IssuePatch
IssueQuery.prepend TicketJourney::IssueQueryPatch unless IssueQuery < TicketJourney::IssueQueryPatch

# Use Redmine's column registry rather than wrapping available_columns. Legacy
# plugins that alias that method (including Kanban) can recurse into a prepend.
unless IssueQuery.available_columns.any? { |column| column.name == :tj_return_count }
  IssueQuery.available_columns << QueryColumn.new(
    :tj_return_count, caption: :field_tj_return_count,
    sortable: -> { TicketJourney::ReturnCount.sql }, default_order: 'desc'
  )
end

Redmine::Plugin.register :redmine_ticket_journey do
  name        'PMO Dashboard'
  author      'Manage Petro'
  description 'Calculates V10 ticket journey durations, return counters, and calendar totals by tracker family.'
  version     '1.0.0'
  url         ''
  author_url  ''

  requires_redmine version_or_higher: '6.0.0'

  # Register as a project module so it appears in Settings > Modules.
  project_module :ticket_journey do
    permission :view_ticket_journey, { ticket_journey: [:index, :show, :export, :pmo_control, :executive_overview, :executive_team_performance, :executive_bug_quality_risk, :executive_technical_debt, :sprint_delivery, :planning_estimation, :owner_returns, :qa_returns, :consecutive_returns, :owner_workload, :status_snapshot, :time_utilization, :aging_risk, :priority_risk, :cycle_distribution, :flow_report, :project_health, :release_readiness, :bug_analysis, :data_quality, :original_sprint] }, read: true
  end

  # Add a menu item under the project menu.
  menu :project_menu,
       :ticket_journey,
       { controller: 'ticket_journey', action: 'pmo_control' },
       caption: 'PMO Dashboard',
       after:   :activity,
       param:   :project_id
end
