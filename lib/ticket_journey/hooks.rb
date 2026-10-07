module TicketJourney
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_issues_show_details_bottom, partial: 'ticket_journey/issue_return_count'
  end
end
