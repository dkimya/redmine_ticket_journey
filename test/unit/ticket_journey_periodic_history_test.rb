require File.expand_path('../test_helper', __dir__)

class TicketJourneyPeriodicHistoryTest < ActiveSupport::TestCase
  fixtures :all

  test 'history retains owners statuses and due edits including future changes but no notes' do
    issue = Issue.find(1)
    date = Date.new(2020, 1, 15)
    before = Journal.create!(journalized: issue, user: User.find(1), created_on: (date - 1).in_time_zone, notes: 'Not loaded')
    before.details.create!(property: 'cf', prop_key: '57', old_value: '', value: '1')
    before.details.create!(property: 'attr', prop_key: 'status_id', old_value: '1', value: '2')
    before.details.create!(property: 'attr', prop_key: 'description', old_value: 'Old', value: 'New')
    after = Journal.create!(journalized: issue, user: User.find(1), created_on: (date + 1).in_time_zone)
    after.details.create!(property: 'cf', prop_key: '57', old_value: '1', value: '2')
    after.details.create!(property: 'attr', prop_key: 'status_id', old_value: '2', value: '5')
    after.details.create!(property: 'attr', prop_key: 'due_date', old_value: date.to_s, value: (date + 2).to_s)
    after.details.create!(property: 'cf', prop_key: '66', old_value: 'Bug', value: 'Merge / Integration Conflict')
    history = TicketJourneyPeriodicTickets.history_for([issue.id], date).fetch(issue.id)
    selected = history.select { |entry| [before.id, after.id].include?(entry.id) }
    assert_equal [before.id, after.id], selected.map(&:id)
    assert_equal ['57', 'status_id'], selected.first.details.map(&:prop_key)
    assert_equal ['57', 'status_id', 'due_date'], selected.last.details.map(&:prop_key)
    assert selected.none? { |entry| entry.respond_to?(:notes) }
    returns_history = TicketJourneyPeriodicTickets.history_for([issue.id], date, include_return_reason: true).fetch(issue.id)
    after_returns = returns_history.find { |entry| entry.id == after.id }
    assert_equal ['57', 'status_id', 'due_date', '66'], after_returns.details.map(&:prop_key)
  end

  test 'snapshots rewind status and keep current owner schedule weight and current followup' do
    first_day, last_day = Date.new(2026, 3, 1), Date.new(2026, 3, 31)
    history = [TicketJourneyPerformance::HistoryJournal.new(1, first_day.in_time_zone, [
      TicketJourneyPerformance::HistoryDetail.new('attr', 'status_id', '2', '5', 1)
    ]), TicketJourneyPerformance::HistoryJournal.new(2, (last_day + 1).in_time_zone, [
      TicketJourneyPerformance::HistoryDetail.new('attr', 'status_id', '5', '2', 2)
    ])]
    issue = stub(id: 99, created_on: (first_day - 10).in_time_zone, status_id: 2,
      due_date: first_day - 2, start_date: first_day - 5, priority: stub(name: 'Immediate/Hot Fix'),
      project_id: 1, project: stub(name: 'Project'), tracker: stub(name: 'Bug'), subject: 'Ticket')
    values = [TicketJourneyPerformance::FieldValue.new(stub(id: 70), '8')]
    statuses = { '2' => stub(name: 'In Progress', is_closed: false), '5' => stub(name: 'Done / Closed', is_closed: true) }
    row = TicketJourneyPeriodicTickets.row(issue, first_day, last_day, statuses, history, values, '2')
    assert_equal '2', row[:owner_id]
    assert_equal first_day - 2, row[:due]
    assert_equal 8.0, row[:weight]
    assert_equal 'Done / Closed', row[:status_name]
    assert row[:done]
    assert_not row[:current_done]
    assert_equal 'In Progress', row[:current_status_name]
    assert_includes row[:extraordinary_reasons], 'Reopened after Done / Closed'
    report = TicketJourneyPeriodicTickets.calculate([row], first_day, last_day)
    assert_empty report[:sets]['completed']
    assert_equal [99], report[:sets]['debt'].map { |entry| entry[:id] }
    assert row[:current_open]
    assert row[:beginning_open]
    assert row[:hotfix]
    assert_equal first_day, row[:delivered_at]
    assert_nil row[:assigned_on]
    # An opening On-Hold is open debt when the ticket is currently eligible.
    statuses['2'] = stub(name: 'On-Hold', is_closed: false)
    statuses['3'] = stub(name: 'In Progress', is_closed: false)
    issue.stubs(:status_id).returns(3)
    history << TicketJourneyPerformance::HistoryJournal.new(3, (last_day + 2).in_time_zone, [
      TicketJourneyPerformance::HistoryDetail.new('attr', 'status_id', '2', '3', 3)
    ])
    active = TicketJourneyPeriodicTickets.row(issue, first_day, last_day, statuses, history, values, '2')
    assert active[:beginning_open]
    assert_equal [99], TicketJourneyPeriodicTickets.calculate([active], first_day, last_day)[:sets]['beginning'].map { |entry| entry[:id] }
    audit = TicketJourneyPeriodicTickets.calculate([active], first_day, last_day)
    assert_empty audit[:sets]['excluded']
    assert_equal [99], audit[:sets]['archived_on_hold_period'].map { |entry| entry[:id] }
  end

  test 'archived during period is audited after reactivation even without an opening snapshot' do
    first, last = Date.new(2026, 3, 1), Date.new(2026, 3, 31)
    states = { '7' => stub(name: 'Archived', is_closed: true), '2' => stub(name: 'In Progress', is_closed: false) }
    issue = stub(id: 99, created_on: (first + 1).in_time_zone, status_id: 2, due_date: last,
      start_date: nil, priority: stub(name: 'Normal'), project_id: 1, project: stub(name: 'Project'),
      tracker: stub(name: 'Bug'), subject: 'Reactivated')
    history = [TicketJourneyPerformance::HistoryJournal.new(1, (first + 2).in_time_zone, [
      TicketJourneyPerformance::HistoryDetail.new('attr', 'status_id', '7', '2', 1)
    ])]
    row = TicketJourneyPeriodicTickets.row(issue, first, last, states, history, [], '1')
    report = TicketJourneyPeriodicTickets.calculate([row], first, last)
    assert_empty report[:sets]['excluded']
    assert_equal [99], report[:sets]['archived_on_hold_period'].map { |item| item[:id] }
  end
end
