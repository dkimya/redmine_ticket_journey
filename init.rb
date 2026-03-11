Redmine::Plugin.register :redmine_ticket_journey do
  name        'Ticket Journey Duration Report'
  author      'Manage Petro'
  description 'Calculates D1–D7-aug durations for each issue based on status change history (Ticket Journey Map V03HA)'
  version     '1.0.0'
  url         ''
  author_url  ''

  requires_redmine version_or_higher: '4.0.0'

  # Register as a project module — makes it appear in Settings > Modules
  project_module :ticket_journey do
    permission :view_ticket_journey, { ticket_journey: [:index, :show, :export] }, read: true
  end

  # Add a menu item under the project menu
  menu :project_menu,
       :ticket_journey,
       { controller: 'ticket_journey', action: 'index' },
       caption: 'Journey Report',
       after:   :activity,
       param:   :project_id
end
