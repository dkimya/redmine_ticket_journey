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
    permission :view_ticket_journey, { ticket_journey: [:index, :show, :export, :owner_returns, :flow_report, :project_health, :release_readiness, :bug_analysis] }, read: true
  end

  # Add a menu item under the project menu.
  menu :project_menu,
       :ticket_journey,
       { controller: 'ticket_journey', action: 'index' },
       caption: 'Journey Report',
       after:   :activity,
       param:   :project_id
end
