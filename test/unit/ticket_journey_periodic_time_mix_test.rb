require File.expand_path('../test_helper', __dir__)

class TicketJourneyPeriodicTimeMixTest < ActiveSupport::TestCase
  setup do
    @first, @last = Date.new(2026, 3, 1), Date.new(2026, 3, 31)
  end

  test 'selected users and all package contributors are distinct scopes including archived paid effort' do
    rows = [row(1, entries: [entry('1', '10', 6), entry('2', '20', 2)]),
      row(2, owner_id: '2', due: nil, entries: [entry('1', '20', 3)]),
      row(3, current_status_name: 'Archived', entries: [entry('1', '10', 4), entry('3', '20', 2)]),
      row(4, current_status_name: 'On-Hold', entries: [entry('1', '20', 1)]),
      row(5, current_status_name: 'Ongoing', entries: [entry('1', '20', 2)])]
    result = calculate(rows)
    assert_equal 16.0, result[:personal_summary][:total]
    assert_equal 8.0, result[:package_summary][:total]
    assert_equal 75.0, result[:package_summary][:development_share]
    assert_equal 75.0, result[:package_summary][:owner_share]
    assert_equal ['1', '2'], result[:package].map { |item| item[:user_id] }
    assert_equal %w[expected_unfinished other archived excluded ongoing], result[:personal].map { |item| item[:category] }
    assert_equal 1, result[:package_summary][:tickets]
    assert_equal 5, result[:personal_summary][:tickets]
    assert_equal 6.0, TicketJourneyPeriodicTimeMix.summarize(result[:archived], ['10'])[:total]
    assert_equal ['1', '3'], result[:archived].map { |item| item[:user_id] }
  end

  test 'multiple package owners never duplicate package costs or transfer booked hours' do
    rows = [row(1, entries: [entry('1', '10', 6), entry('2', '20', 2)]),
      row(2, owner_id: '2', entries: [entry('1', '10', 3)])]
    result = calculate(rows, owners: %w[1 2])
    assert_equal 11.0, result[:package_summary][:total]
    assert_equal 11.0, result[:personal_summary][:total]
    assert_equal 2, result[:package_summary][:tickets]
    assert_equal [1, 2], result[:personal].select { |item| item[:user_id] == '1' }.map { |item| item[:issue_id] }
    assert_in_delta 900.0 / 11, result[:package_summary][:development_share]
    assert_in_delta 600.0 / 11, result[:package_summary][:owner_share]
  end

  test 'missing activity mapping permission gaps and invalid hours never invent healthy ratios' do
    rows = [row(1, entries: [entry('1', '10', 6)])]
    unmapped = calculate(rows, development: [])
    assert_equal 6.0, unmapped[:package_summary][:total]
    assert_nil unmapped[:package_summary][:development_share]
    rows.first[:mix_records] << entry('2', '20', nil).merge(invalid_count: 1)
    invalid = calculate(rows)
    assert_nil invalid[:package_summary][:total]
    assert_nil invalid[:package_summary][:development_share]
    assert_equal 6.0, invalid[:package_summary][:known]
    assert_equal 1, invalid[:package_summary][:invalid]
    partial = calculate([row(2, entries: [entry('1', '10', 3)])], available: false)
    assert_nil partial[:personal_summary][:total]
    assert_nil partial[:personal_summary][:development_share]
    assert_equal 3.0, partial[:personal_summary][:known]
    zero = calculate([row(3, entries: [entry('1', '20', 3)])])
    assert_equal 0.0, zero[:package_summary][:development_share]
    assert_nil calculate([])[:package_summary][:development_share]
  end

  test 'work dates are bounded and hidden owners do not leak into package attribution' do
    rows = [row(1, owner_visible: false, entries: [entry('1', '10', 3), entry('1', '10', 9, @first - 1), entry('1', '10', 8, @last + 1)]),
      row(2, time_allowed: false, entries: [entry('1', '10', 99)])]
    result = calculate(rows)
    assert_empty result[:package]
    assert_equal 3.0, result[:personal_summary][:total]
    assert_equal ['unclassified'], result[:personal].map { |item| item[:category] }
  end

  private

  def calculate(rows, owners: ['1'], development: ['10'], available: true)
    owners = owners.map do |id|
      own = rows.select { |item| item[:owner_visible] && item[:owner_id] == id }
      { owner: stub(id: id.to_i), report: { tickets: TicketJourneyPeriodicTickets.calculate(own, @first, @last, with_trends: false) } }
    end
    TicketJourneyPeriodicTimeMix.calculate(rows, owners, @first, @last, development, available: available)
  end

  def entry(user, activity, hours, day = @first + 2)
    { user_id: user, activity_id: activity, hours: hours, day: day }
  end

  def row(id, entries: [], **options)
    { id: id, owner_id: '1', owner_visible: true, due: @first + 5, beginning_open: false,
      closed_before: false, hotfix: false, done: false, status_name: 'In Progress', current_open: true,
      weight: 5.0, missing_weight: false, time_allowed: true, mix_records: entries,
      subject: 'Ticket', tracker_name: 'Bug', project_name: 'Project' }.merge(options)
  end
end
