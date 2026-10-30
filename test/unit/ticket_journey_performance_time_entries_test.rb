require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceTimeEntriesTest < ActiveSupport::TestCase
  fixtures :all

  test 'Time uses visible direct work dates with no parent rollup and excludes invalid hours' do
    User.current = User.find(1)
    issue = Issue.find(1)
    date = Date.new(2026, 10, 13)
    TimeEntry.where(issue_id: issue.id).delete_all
    activity = issue.project.activities.first
    create_entry = lambda do |day, hours, author|
      TimeEntry.create!(project: issue.project, issue: issue, user: author, author: author,
        activity: activity, spent_on: day, hours: hours)
    end
    older = create_entry.call(date - 1, 2, User.find(1))
    # A recently created backdated record still contributes under work-date rules.
    older.update_columns(created_on: date + 5, updated_on: date + 5)
    create_entry.call(date, 3, User.find(2))
    create_entry.call(date + 1, 100, User.find(1))
    invalid = create_entry.call(date, 1, User.find(1))
    invalid.update_column(:hours, -50)
    result = TicketJourneyPerformanceTime.hours_for([issue.id], date)
    assert_equal 5.0, TicketJourneyPerformanceTime.spent(result[issue.id], date)
    assert_equal 2.0, TicketJourneyPerformanceTime.spent(result[issue.id], date - 1)
    owners = TicketJourneyPerformanceTime.owner_hours_for([issue.id], [1, 2], date, by_day: true)
    assert_equal 2.0, TicketJourneyPerformanceTime.spent(owners.fetch([issue.id, 1]), date)
    assert_equal 0.0, TicketJourneyPerformanceTime.spent(owners.fetch([issue.id, 2]), date - 1)
    assert_equal 3.0, TicketJourneyPerformanceTime.spent(owners.fetch([issue.id, 2]), date)
    logged = TicketJourneyPerformanceTimeTrends.logged_hours_for([issue.project_id], [2], date - 1, date)
    assert_equal({ [2, date] => 3.0 }, logged)
    assert_empty TicketJourneyPerformanceTimeTrends.logged_hours_for([], [1, 2], date - 1, date)
    assert result.keys.all? { |id| id == issue.id }, 'Only requested direct issue IDs may contribute'
    TimeEntry.expects(:visible).with(User.current).returns(TimeEntry.none)
    assert_empty TicketJourneyPerformanceTime.hours_for([issue.id], date)
  ensure
    User.current = nil
  end
end
