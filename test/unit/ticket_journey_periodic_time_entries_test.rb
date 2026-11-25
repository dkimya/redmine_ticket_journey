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
    bad_same_group = make.call(first + 1, 1, User.find(1), User.find(1))
    bad_same_group.update_column(:hours, -2)
    make.call(last, 1, User.find(1), User.find(1)).update_column(:hours, 0)

    count_aggregates = lambda do |**options|
      queries = []
      subscriber = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] }
      hours = ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
        TimeEntry.uncached { TicketJourneyPeriodicTime.load_hours([issue.id], first, last, ['1'], **options) }
      end
      [hours, queries.count { |sql| sql.match?(/\b(?:SUM|COUNT)\(/i) && sql.match?(/\btime_entries\b/i) }]
    end

    hours, query_count = count_aggregates.call
    assert_equal 3, query_count
    assert_equal 10.0, hours[:costs][issue.id]
    assert_equal 2, hours[:invalid_costs][issue.id]
    assert_equal({ [issue.id, 1, first] => 1, [issue.id, 1, first + 1] => 1 }, hours[:invalid_logs])
    assert_equal [[first + 1, 2.0], [last, 0.0]], hours[:logs][issue.id]['1'].sort
    same_group = hours[:mix][issue.id].select { |entry| entry[:day] == first + 1 }
    assert_equal 2.0, same_group.find { |entry| entry[:hours] }[:hours]
    assert_equal 1, same_group.find { |entry| entry[:hours].nil? }[:invalid_count]
    invalid_only = hours[:mix][issue.id].select { |entry| entry[:day] == first }
    assert_equal [[nil, 1]], invalid_only.map { |entry| entry.values_at(:hours, :invalid_count) }
    assert_equal ['1', '2'], hours[:mix][issue.id].map { |entry| entry[:user_id] }.uniq.sort

    owner_hours, query_count = count_aggregates.call(owner_only: true)
    assert_equal 1, query_count
    assert_equal hours[:logs], owner_hours[:logs]
    assert_equal hours[:invalid_logs], owner_hours[:invalid_logs]
    assert_empty owner_hours[:costs]
    assert_empty owner_hours[:invalid_costs]

    TimeEntry.expects(:visible).with(User.current).at_least_once.returns(TimeEntry.none)
    hidden = TicketJourneyPeriodicTime.load_hours([issue.id], first, last, ['1'])
    assert_empty hidden[:costs]
    assert_empty hidden[:logs]
    assert_empty hidden[:invalid_costs]
    assert_empty hidden[:invalid_logs]
    assert_empty hidden[:mix]
  ensure
    User.current = nil
  end
end
