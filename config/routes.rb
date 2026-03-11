Rails.application.routes.draw do
  scope '/projects/:project_id' do
    get  'ticket_journey',              to: 'ticket_journey#index',    as: 'ticket_journey'
    get  'ticket_journey/issue/:id',    to: 'ticket_journey#show',     as: 'ticket_journey_issue'
    get  'ticket_journey/export',       to: 'ticket_journey#export',   as: 'ticket_journey_export'
  end
end
