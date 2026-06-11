Redmine::Plugin.register :redmine_ticket_journey do
  name        'Ticket Journey Duration Report'
  author      'Manage Petro'
  description 'Calculates V10 ticket journey durations, return counters, and calendar totals by tracker family.'
  version     '1.0.0'
  url         ''
  author_url  ''

  requires_redmine version_or_higher: '6.0.0'

  # Register as a project module so it appears in Settings > Modules.
  project_module :ticket_journey do
    permission :view_ticket_journey, { ticket_journey: [:index, :show, :export, :pmo_control, :executive_overview, :executive_team_performance, :executive_bug_quality_risk, :executive_technical_debt, :sprint_delivery, :planning_estimation, :owner_returns, :qa_returns, :owner_workload, :status_snapshot, :time_utilization, :aging_risk, :priority_risk, :cycle_distribution, :flow_report, :project_health, :release_readiness, :bug_analysis, :data_quality, :original_sprint] }, read: true
  end

  # Add a menu item under the project menu.
  menu :project_menu,
       :ticket_journey,
       { controller: 'ticket_journey', action: 'pmo_control' },
       caption: 'Journey Report',
       after:   :activity,
       param:   :project_id
end
