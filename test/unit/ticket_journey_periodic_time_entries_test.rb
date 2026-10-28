require File.expand_path('../test_helper', __dir__)

class TicketJourneyPeriodicTimeEntriesTest < ActiveSupport::TestCase
  fixtures :all

  test 'ticket cost and personal logs use distinct windows and logged users not entry creators' do
    User.current = User.find(1)
    issue = Issue.find(1)
    first, last = Date.new(2026, 3, 2), Date.new(2026, 3, 6)
    TimeEntry.where(issue_id: issue.id).delete_all
    activity = issue.project.activities.first
    make = lambda do |day, hours, user, creator|
      TimeEntry.create!(project: issue.project, issue: issue, activity: activity, spent_on: day,
        hours: hours, user: user, author: creator)
    end
    old = make.call(first - 2, 5, User.find(1), User.find(1))
    old.update_columns(created_on: (last + 10).in_time_zone, updated_on: (last + 10).in_time_zone)
    make.call(first + 1, 2, User.find(1), User.find(1))
    make.call(first + 2, 3, User.find(2), User.find(1))
    make.call(last + 1, 99, User.find(1), User.find(1))
    hours = TicketJourneyPeriodicTime.load_hours([issue.id], first, last, ['1', '2'])
    assert_equal 10.0, hours[:costs][issue.id]
    assert_equal [[first + 1, 2.0]], hours[:logs][issue.id]['1']
    assert_equal [[first + 2, 3.0]], hours[:logs][issue.id]['2']
    assert_equal [issue.id], hours[:costs].keys
    assert_equal 5.0, hours[:mix][issue.id].sum { |entry| entry[:hours] }
    assert_equal ['1', '2'], hours[:mix][issue.id].map { |entry| entry[:user_id] }.sort
    assert hours[:mix][issue.id].all? { |entry| entry[:activity_id] == activity.id.to_s && entry[:day].between?(first, last) }
    bad = make.call(first, 1, User.find(1), User.find(1))
    bad.update_column(:hours, -5)
    hours = TicketJourneyPeriodicTime.load_hours([issue.id], first, last, ['1'])
    assert_equal 10.0, hours[:costs][issue.id]
    assert_equal 1, hours[:invalid_costs][issue.id]
    assert_equal 1, hours[:invalid_logs][[issue.id, 1, first]]
    assert_equal 1, hours[:mix][issue.id].count { |entry| entry[:hours].nil? }
    assert_equal ['1', '2'], hours[:mix][issue.id].map { |entry| entry[:user_id] }.uniq.sort
    TimeEntry.expects(:visible).with(User.current).at_least_once.returns(TimeEntry.none)
    hidden = TicketJourneyPeriodicTime.load_hours([issue.id], first, last, ['1'])
    assert_empty hidden[:costs]
    assert_empty hidden[:logs]
  ensure
    User.current = nil
  end
end
