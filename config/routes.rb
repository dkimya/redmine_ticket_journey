Rails.application.routes.draw do
  scope '/projects/:project_id' do
    get  'ticket_journey',              to: 'ticket_journey#index',    as: 'ticket_journey'
    get  'ticket_journey/owner_returns', to: 'ticket_journey#owner_returns', as: 'ticket_journey_owner_returns'
    get  'ticket_journey/owner_workload', to: 'ticket_journey#owner_workload', as: 'ticket_journey_owner_workload'
    get  'ticket_journey/aging_risk', to: 'ticket_journey#aging_risk', as: 'ticket_journey_aging_risk'
    get  'ticket_journey/flow_report',  to: 'ticket_journey#flow_report', as: 'ticket_journey_flow_report'
    get  'ticket_journey/project_health', to: 'ticket_journey#project_health', as: 'ticket_journey_project_health'
    get  'ticket_journey/release_readiness', to: 'ticket_journey#release_readiness', as: 'ticket_journey_release_readiness'
    get  'ticket_journey/bug_analysis', to: 'ticket_journey#bug_analysis', as: 'ticket_journey_bug_analysis'
    get  'ticket_journey/issue/:id',    to: 'ticket_journey#show',     as: 'ticket_journey_issue'
    get  'ticket_journey/export',       to: 'ticket_journey#export',   as: 'ticket_journey_export'
  end
end
