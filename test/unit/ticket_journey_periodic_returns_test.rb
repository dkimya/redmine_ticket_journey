require File.expand_path('../test_helper', __dir__)

class TicketJourneyPeriodicReturnsTest < ActiveSupport::TestCase
  setup do
    @first, @last = Date.new(2026, 3, 1), Date.new(2026, 3, 31)
  end

  test 'primary population matches completed expectations and separates all done work' do
    rows = [row(1, 2), row(2, 0), row(3, 4, due: nil),
      row(4, 9, done: false), row(5, 9, status_name: 'Archived'),
      row(6, 9, delivered_at: @first - 1), row(7, 9, delivered_at: nil)]
    tickets = TicketJourneyPeriodicTickets.calculate(rows, @first, @last)
    result = TicketJourneyPeriodicReturns.calculate(tickets, @first, @last)
    assert_equal tickets[:sets]['completed'].map { |item| item[:id] }, result[:sets]['returns_open'].map { |item| item[:id] }
    assert_equal tickets[:sets]['actual'].map { |item| item[:id] }, result[:sets]['total_open'].map { |item| item[:id] }
    assert_equal 2, result[:expected][:population]
    assert_equal 1, result[:expected][:returned]
    assert_equal 2.0, result[:expected][:ratio]
    assert_equal 3, result[:total][:population]
    assert_equal 2, result[:total][:returned]
    assert_equal 3.0, result[:total][:ratio]
  end

  test 'sample 8 incidents among 5 returned tickets gives 1 point 6 not percent or whole-population average' do
    counts = [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 3]
    rows = counts.each_with_index.map { |count, index| row(index + 1, count, repeats: [count - 1, 0].max) }
    result = calculate(rows)[:expected]
    assert_equal 12, result[:population]
    assert_equal 5, result[:returned]
    assert_equal 8, result[:incidents]
    assert_equal 1.6, result[:ratio]
    assert_equal [7, 3, 1, 1, 0], (0..4).map { |index| result[:sets]["returns_#{index}"].size }
    assert_equal 2, result[:with_repeats]
    assert_equal [1, 1, 0], (1..3).map { |index| result[:sets]["repeats_#{index}"].size }
  end

  test 'current reopened and excluded tickets cannot enter either done population or trends' do
    result = calculate([row(1, 3, current_done: false), row(2, 4, current_status_name: 'On-Hold'), row(3, 1)])
    assert_equal [3], result[:sets]['returns_open'].map { |item| item[:id] }
    assert_equal [3], result[:sets]['total_open'].map { |item| item[:id] }
    assert_equal 1, result[:trends].sum { |point| point[:population] }
    assert_equal 1, result[:expected][:incidents]
  end

  test 'non-Merge averages use full through-RED incidents and all returned tickets in each population' do
    merge = row(1, 2)
    merge[:events] = Array.new(2) { { merge_conflict: true } }
    regular = row(2, 3)
    other = row(3, 4, due: @last + 1)
    result = calculate([merge, regular, other, row(4, 0)])
    assert_equal 1.5, result[:expected][:adjusted_ratio]
    assert_in_delta 7.0 / 3, result[:total][:adjusted_ratio]
    assert_equal [1, 2], result[:sets]['non_merge_denominator'].map { |item| item[:id] }
    assert_equal [2], result[:sets]['non_merge_incidents'].map { |item| item[:id] }
    assert_equal [2, 3], result[:sets]['total_non_merge_incidents'].map { |item| item[:id] }
    assert_equal 3, result[:trends].sum { |point| point[:non_merge] }
    point = result[:trends].find { |entry| entry[:returned].positive? }
    assert_equal 1.5, point[:adjusted_ratio]
    regular[:events][0][:merge_conflict] = nil
    unavailable = calculate([merge, regular])
    assert_nil unavailable[:expected][:adjusted_ratio]
    assert_equal 2.5, unavailable[:expected][:ratio]
    assert_equal [2], unavailable[:sets]['unknown_return_reasons'].map { |item| item[:id] }
  end

  test 'repeat distribution uses repeat tickets not all returned tickets and upper buckets are exclusive' do
    result = calculate([row(1, 1), row(2, 2, repeats: 1), row(3, 3, repeats: 2), row(4, 5, repeats: 4)])[:expected]
    assert_equal 4, result[:returned]
    assert_equal 3, result[:with_repeats]
    assert_equal [1, 1, 1], (1..3).map { |index| result[:sets]["repeats_#{index}"].size }
    assert_equal [1, 1, 1, 1], (1..4).map { |index| result[:sets]["returns_#{index}"].size }
  end

  test 'zero returned tickets distinguishes an empty delivery cohort from no-return delivery' do
    empty, zero = calculate([])[:expected], calculate([row(1, 0)])[:expected]
    assert_equal 0, empty[:population]
    assert_equal 1, zero[:population]
    [empty, zero].each do |result|
      assert_equal 0, result[:incidents]
      assert_equal 0, result[:returned]
      assert_nil result[:ratio]
    end
  end

  test 'team ratios use summed denominators and retain zero-output owners' do
    a = [row(1, 4, owner_id: '1')]
    b = (2..5).map { |id| row(id, 1, owner_id: '2') }
    first, second, team = calculate(a), calculate(b), calculate(a + b)
    assert_equal 4.0, first[:expected][:ratio]
    assert_equal 1.0, second[:expected][:ratio]
    assert_equal 1.6, team[:expected][:ratio]
    assert_equal 0, calculate([])[:expected][:population]
    assert_equal first[:expected][:incidents] + second[:expected][:incidents], team[:expected][:incidents]
  end

  test 'weekly cohorts partition final completed population without cumulative or per-week expectation rebuilding' do
    rows = [row(1, 2, delivered_at: @first), row(2, 1, delivered_at: @first + 1),
      row(3, 0, delivered_at: @last), row(4, 3, due: nil)]
    result = calculate(rows)
    assert_equal [@first, @first], result[:trends].first.values_at(:start, :date)
    assert_equal @last, result[:trends].last[:date]
    assert_equal result[:expected][:population], result[:trends].sum { |point| point[:population] }
    assert_equal result[:expected][:incidents], result[:trends].sum { |point| point[:incidents] }
    assert_equal result[:expected][:returned], result[:trends].sum { |point| point[:returned] }
    assert_equal 2.0, result[:trends].first[:ratio]
    assert_equal 1.0, result[:trends][1][:ratio]
    assert_nil result[:trends].last[:ratio]
    result[:trends].each do |point|
      contributors = TicketJourneyPeriodicReturns.cohort_rows(result[:sets]['returns_open'], point[:start], point[:date])
      assert_equal contributors.size, point[:population]
      assert_equal contributors.sum { |item| item[:return_count] }, point[:incidents]
    end
  end

  test 'single-day and monthly intervals have no gaps overlaps opening cohort or future dates' do
    assert_equal [[@first, @first]], TicketJourneyPeriodicReturns.intervals(@first, @first)
    intervals = TicketJourneyPeriodicReturns.intervals(Date.new(2024, 2, 15), Date.new(2024, 8, 2))
    assert_equal [Date.new(2024, 2, 15), Date.new(2024, 2, 29)], intervals.first
    assert_equal [Date.new(2024, 8, 1), Date.new(2024, 8, 2)], intervals.last
    intervals.each_cons(2) { |left, right| assert_equal left.last + 1, right.first }
  end

  test 'event enrichment includes earlier returns excludes future returns and never reveals hidden reasons' do
    issue = stub(tracker: stub(name: 'Bug'))
    statuses = { '1' => stub(name: 'Feedback'), '2' => stub(name: 'Returned') }
    history = [@first - 10, @first + 1, @last + 1].each_with_index.map do |date, index|
      TicketJourneyPerformance::HistoryJournal.new(index + 1, date.in_time_zone, [
        TicketJourneyPerformance::HistoryDetail.new('attr', 'status_id', '1', '2', index + 1)
      ])
    end
    enriched = TicketJourneyPeriodicReturns.enrich(row(1, 0), issue, history, statuses, @last, [])
    assert_equal 2, enriched[:return_count]
    assert_equal 1, enriched[:repeat_count]
    assert enriched[:events].all? { |event| event[:reason].nil? && event[:merge_conflict].nil? }
    values = [TicketJourneyPerformance::FieldValue.new(stub(id: 66), 'Merge / Integration Conflict')]
    merge = TicketJourneyPeriodicReturns.enrich(row(1, 0), issue, history, statuses, @last, values)
    assert_equal 2.0, calculate([merge])[:expected][:ratio]
    assert merge[:events].all? { |event| event[:merge_conflict] }
  end

  private

  def calculate(rows)
    tickets = TicketJourneyPeriodicTickets.calculate(rows, @first, @last, with_trends: false)
    TicketJourneyPeriodicReturns.calculate(tickets, @first, @last)
  end

  def row(id, count, repeats: 0, **options)
    { id: id, owner_id: '1', due: @first + 5, beginning_open: false, closed_before: false,
      assigned_on: @first, hotfix: false, done: true, delivered_at: @first + 2,
      status_name: 'Done / Closed', current_open: false, weight: 5.0, missing_weight: false,
      return_count: count, repeat_count: repeats, events: Array.new(count) { { merge_conflict: false } } }.merge(options)
  end
end
