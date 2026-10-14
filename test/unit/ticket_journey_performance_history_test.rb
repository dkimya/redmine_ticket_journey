require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceHistoryTest < ActiveSupport::TestCase
  fixtures :all

  test 'compact history excludes notes unrelated details past owners and other tickets' do
    issue = Issue.find(1)
    date = Date.new(2020, 1, 15)
    before = Journal.create!(journalized: issue, user: User.find(1), created_on: date.in_time_zone - 1.day,
                             notes: 'Unrelated text ' * 1000)
    before.details.create!(property: 'attr', prop_key: 'status_id', old_value: '1', value: '2')
    before.details.create!(property: 'attr', prop_key: 'description', old_value: 'Old text', value: 'New text')
    before.details.create!(property: 'cf', prop_key: '57', old_value: '1', value: '2')
    after = Journal.create!(journalized: issue, user: User.find(1), created_on: (date + 1).in_time_zone)
    after.details.create!(property: 'cf', prop_key: '57', old_value: '', value: '3')
    after.details.create!(property: 'attr', prop_key: 'status_id', old_value: '2', value: '5')
    other = Journal.create!(journalized: Issue.find(2), user: User.find(1), created_on: date.in_time_zone)
    other.details.create!(property: 'attr', prop_key: 'status_id', old_value: '1', value: '2')

    history = Issue.uncached { TicketJourneyPerformance.history_for([issue.id], date) }
    assert_equal [issue.id], history.keys
    selected = history[issue.id].select { |entry| [before.id, after.id].include?(entry.id) }
    assert_equal [before.id, after.id], selected.map(&:id)
    assert_equal ['status_id'], selected.first.details.map(&:prop_key)
    assert_equal ['57', 'status_id'], selected.last.details.map(&:prop_key)
    assert_equal '', selected.last.details.first.old_value
    assert selected.none? { |entry| entry.respond_to?(:notes) }
  end
end
