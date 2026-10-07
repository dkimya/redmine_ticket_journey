require File.expand_path('../test_helper', __dir__)

class TicketJourneyNativeReturnCountTest < ActiveSupport::TestCase
  fixtures :all

  setup do
    User.current = User.find(1)
    @issue = Issue.find(1)
    @issue.journals.destroy_all
    @issue.tracker.update_column(:name, 'Bug')
    @statuses = %w[Feedback Review Returned].each_with_object({}) do |name, result|
      result[name] = IssueStatus.find_or_create_by!(name: name)
    end
    @statuses['Done / Closed'] = IssueStatus.find_or_create_by!(name: 'Done / Closed') { |status| status.is_closed = true }
  end

  teardown do
    User.current = nil
  end

  test 'native count agrees with report and does not reset after completion' do
    add_transition(@issue, 'Review', 'Returned')
    add_transition(@issue, 'Returned', 'Review')
    add_transition(@issue, 'Review', 'Done / Closed')
    add_transition(@issue, 'Done / Closed', 'Returned')
    add_transition(@issue, 'Returned', 'Returned')
    add_transition(@issue, 'Feedback', 'Returned')
    assert_equal 3, @issue.tj_return_count

    controller = TicketJourneyController.new
    transitions = controller.send(:load_transitions, @issue)[@issue.id]
    events = controller.send(:cumulative_return_events, :internal, transitions)
    assert_equal events.size, @issue.tj_return_count

    durations = controller.send(:apply_return_counters, {}, :internal, transitions)
    assert_equal @issue.tj_return_count, TicketJourneyController::ALL_COUNTER_KEYS.sum { |key| durations[key] }
  end

  test 'native count follows task and excluded journey family rules' do
    add_transition(@issue, 'Review', 'Returned')
    add_transition(@issue, 'Feedback', 'Returned')
    add_transition(@issue, 'Done / Closed', 'Returned')

    @issue.tracker.update_column(:name, 'Task (Business Jobs)')
    assert_equal 2, @issue.tj_return_count
    @issue.tracker.update_column(:name, 'Customer Support')
    assert_equal 0, @issue.tj_return_count
    @issue.tracker.update_column(:name, 'Epic')
    assert_equal 0, @issue.tj_return_count
    @issue.tracker.update_column(:name, 'Unconfigured Tracker')
    assert_equal 3, @issue.tj_return_count
  end

  test 'column discovery tolerates a legacy plugin alias installed after our patch' do
    query_class = Class.new do
      def available_columns
        [:native_column]
      end
    end
    query_class.prepend TicketJourney::IssueQueryPatch

    # Reproduce Kanban's alias-based wrapper without modifying IssueQuery itself.
    calls = 0
    query_class.class_eval do
      alias_method :available_columns_without_legacy_plugin, :available_columns
      define_method(:available_columns) do
        calls += 1
        raise 'recursive column discovery' if calls > 5

        available_columns_without_legacy_plugin + [:legacy_column]
      end
    end

    assert_equal [:native_column, :legacy_column], query_class.new.available_columns
    assert_equal 1, calls
    assert_equal 1, IssueQuery.available_columns.count { |column| column.name == :tj_return_count }
  end

  test 'filters preserve native and legacy fields without recursive initialization' do
    query_class = Class.new do
      def available_filters
        initialize_available_filters unless @available_filters
        @available_filters
      end

      def initialize_available_filters
        add_available_filter('status_id', type: :list)
      end

      def add_available_filter(field, options)
        (@available_filters ||= {})[field] = options
      end
    end
    query_class.prepend TicketJourney::IssueQueryPatch

    calls = 0
    query_class.class_eval do
      alias_method :initialize_available_filters_without_legacy_plugin, :initialize_available_filters
      define_method(:initialize_available_filters) do
        calls += 1
        raise 'recursive filter initialization' if calls > 5

        initialize_available_filters_without_legacy_plugin
        add_available_filter('legacy_field', type: :integer)
      end
    end

    query = query_class.new
    2.times do
      assert_equal %w[status_id legacy_field tj_return_count], query.available_filters.keys
      assert_equal :integer, query.available_filters['tj_return_count'][:type]
    end
    assert_equal 1, calls
  end

  test 'column is selectable only once and filters use lifetime counts' do
    3.times { add_transition(@issue, 'Review', 'Returned') }
    query = query_for(@issue)
    assert_equal 1, query.available_columns.count { |column| column.name == :tj_return_count }
    assert_equal 1, query.available_columns.count { |column| column.name == :tj_return_count }
    query.column_names = [:id, :tj_return_count]
    query.add_filter('tj_return_count', '>=', ['3'])
    assert query.valid?, query.errors.full_messages.join(', ')
    loaded = query.issues
    assert_equal [@issue.id], loaded.map(&:id)
    column = query.columns.find { |item| item.name == :tj_return_count }
    assert_equal 3, column.value_object(loaded.first)
    # Selected columns are batch-loaded, including the values used by CSV.
    Issue.expects(:where).never
    assert_equal 3, loaded.first.tj_return_count
  end

  test 'zero equality inequality and numeric bounds work through native filters' do
    query = query_for(@issue)
    query.add_filter('tj_return_count', '=', ['0'])
    assert_equal [@issue.id], query.issues.map(&:id)

    add_transition(@issue, 'Review', 'Returned')
    assert_empty query.issues
    query.add_filter('tj_return_count', '!', ['1'])
    assert_empty query.issues
    query.add_filter('tj_return_count', '>=', ['2'])
    assert_empty query.issues
    query.add_filter('tj_return_count', '<=', ['1'])
    assert_equal [@issue.id], query.issues.map(&:id)
  end

  test 'sorting occurs before pagination and reload refreshes a batch-loaded count' do
    other = Issue.find(2)
    other.journals.destroy_all
    other.update_columns(project_id: @issue.project_id, tracker_id: @issue.tracker_id)
    add_transition(@issue, 'Review', 'Returned')
    3.times { add_transition(other, 'Review', 'Returned') }
    query = query_for(@issue, other)
    query.column_names = [:id, :tj_return_count]
    query.sort_criteria = [['tj_return_count', 'desc']]
    loaded = query.issues(limit: 1)
    assert_equal [other.id], loaded.map(&:id)
    assert_equal 3, loaded.first.tj_return_count

    add_transition(other, 'Feedback', 'Returned')
    assert_equal 4, loaded.first.reload.tj_return_count
  end

  test 'new issues show zero and the count has no editable setter' do
    assert_equal 0, Issue.new.tj_return_count
    assert_not Issue.new.respond_to?(:tj_return_count=)
  end

  private

  def query_for(*issues)
    query = IssueQuery.new(name: '_', project: @issue.project)
    query.add_filter('status_id', '*', [''])
    query.add_filter('issue_id', '=', [issues.map(&:id).join(',')])
    query
  end

  def add_transition(issue, from, to)
    journal = Journal.new(journalized: issue, user: User.current)
    journal.notify = false
    journal.details.build(property: 'attr', prop_key: 'status_id',
                          old_value: @statuses.fetch(from).id.to_s, value: @statuses.fetch(to).id.to_s)
    journal.save!
  end
end
