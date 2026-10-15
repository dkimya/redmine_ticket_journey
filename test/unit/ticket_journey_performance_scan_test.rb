require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceScanTest < ActiveSupport::TestCase
  fixtures :all

  setup do
    @date = Date.new(2026, 10, 14)
    @issues = [Issue.find(1), Issue.find(2)]
    @scope = Issue.where(id: @issues.map(&:id))
    @field = IssueCustomField.find_by(id: 57) || IssueCustomField.create!(
      id: 57, name: 'Performance Owner', field_format: 'user', is_for_all: true,
      tracker_ids: Tracker.pluck(:id))
    CustomValue.where(customized_type: 'Issue', customized_id: @issues.map(&:id), custom_field_id: 57).delete_all
    @issues.each do |issue|
      CustomValue.create!(customized: issue, custom_field: @field, value: '2')
    end
  end

  test 'selected owner candidates include reassigned and blank-current-owner tickets' do
    current = CustomValue.find_by(customized_type: 'Issue', customized_id: @issues.first.id, custom_field_id: 57)
    current.update!(value: '')
    journal = Journal.create!(journalized: @issues.first, user: User.find(1), created_on: (@date + 1).in_time_zone)
    journal.details.create!(property: 'cf', prop_key: '57', old_value: '1', value: '')
    assert_equal [@issues.first.id], TicketJourneyPerformance.candidate_scope(@scope, ['1']).pluck(:id)
    assert_equal [@issues.last.id], TicketJourneyPerformance.candidate_scope(@scope, ['2']).pluck(:id)
    assert_empty TicketJourneyPerformance.candidate_scope(Issue.none, ['1']).pluck(:id)
    assert_equal @issues.map(&:id).sort, TicketJourneyPerformance.candidate_scope(@scope, ['1', '2']).pluck(:id).sort
  end

  test 'owner-only discovery excludes status history and matches full snapshot ownership' do
    issue = @issues.first
    journal = Journal.create!(journalized: issue, user: User.find(1), created_on: (@date + 1).in_time_zone)
    journal.details.create!(property: 'cf', prop_key: '57', old_value: '', value: '2')
    journal.details.create!(property: 'attr', prop_key: 'status_id', old_value: '1', value: '2')
    compact = TicketJourneyPerformance.history_for([issue.id], @date, owner_only: true)
    assert_equal ['57'], compact.fetch(issue.id).flat_map { |entry| entry.details.map(&:prop_key) }
    full = TicketJourneyPerformance.history_for([issue.id], @date)
    statuses = IssueStatus.all.index_by { |status| status.id.to_s }
    snapshot = TicketJourneyPerformance.snapshot(issue, @date, statuses, history: full.fetch(issue.id), visible_values: [])
    assert_equal snapshot[:owner_id], TicketJourneyPerformance.owner_at(issue, compact.fetch(issue.id), @date)
    assert_equal '', snapshot[:owner_id]
  end

  test 'metric prefilters preserve date boundaries and leave weight contributors unfiltered' do
    @issues.first.update_columns(due_date: @date + 2)
    @issues.last.update_columns(due_date: @date + 3)
    assert_equal [@issues.first.id], TicketJourneyPerformance.metric_scope(@scope, 'due_soon', @date).pluck(:id)
    @issues.first.update_columns(due_date: @date)
    @issues.last.update_columns(due_date: nil)
    assert_equal [@issues.first.id], TicketJourneyPerformance.metric_scope(@scope, 'due', @date).pluck(:id)
    assert_empty TicketJourneyPerformance.metric_scope(@scope, 'started', @date).pluck(:id)
    assert_equal [@issues.last.id], TicketJourneyPerformance.metric_scope(@scope, 'missing_due', @date).pluck(:id)
    assert_equal @issues.map(&:id).sort, TicketJourneyPerformance.metric_scope(@scope, 'delivered_weight', @date).pluck(:id).sort
  end

  test 'two-field shortcut matches native values and respects an installed visibility override' do
    issue = @issues.first.reload
    User.stubs(:current).returns(User.find(1))
    expected = issue.visible_custom_field_values.select { |value| [57, 70].include?(value.custom_field.id) }
                    .map { |value| [value.custom_field.id, value.value] }.sort
    actual = TicketJourneyPerformance.batch_field_values([issue]).fetch(issue.id)
                    .map { |value| [value.custom_field.id, value.value] }.sort
    assert_equal expected, actual
    # A plugin/test override must retain authority over custom-field visibility.
    issue.stubs(:visible_custom_field_values).returns([])
    assert_empty TicketJourneyPerformance.batch_field_values([issue]).fetch(issue.id)
  end

  test 'candidate and due filtering reproduce full-scan historical contributor IDs' do
    issue = @issues.first
    @issues.each { |entry| entry.update_columns(due_date: @date - 1) }
    journal = Journal.create!(journalized: issue, user: User.find(1), created_on: (@date + 1).in_time_zone)
    journal.details.create!(property: 'cf', prop_key: '57', old_value: '1', value: '2')
    statuses = IssueStatus.all.index_by { |status| status.id.to_s }
    snapshots = lambda do |scope|
      batch = scope.to_a
      history = TicketJourneyPerformance.history_for(batch.map(&:id), @date)
      batch.filter_map do |entry|
        row = TicketJourneyPerformance.snapshot(entry, @date, statuses, history: history.fetch(entry.id, []), visible_values: [])
        row if row[:owner_id] == '1'
      end
    end
    expected = snapshots.call(@scope)
    candidate = TicketJourneyPerformance.metric_scope(TicketJourneyPerformance.candidate_scope(@scope, ['1']), 'due', @date)
    actual = snapshots.call(candidate)
    assert_equal expected.map { |row| row[:id] }, actual.map { |row| row[:id] }
    assert_equal TicketJourneyPerformance.calculate(expected, @date, nil)[:detail_sets]['due'].map { |row| row[:id] },
                 TicketJourneyPerformance.calculate(actual, @date, nil)[:detail_sets]['due'].map { |row| row[:id] }
  end
end
