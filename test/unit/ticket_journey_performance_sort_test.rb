require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceSortTest < ActiveSupport::TestCase
  test 'metric defaults and untrusted sorting parameters use allowed keys' do
    assert_equal ['due', 'asc'], TicketJourneyPerformance.detail_sort_options('open', nil, nil)
    assert_equal ['completion', 'desc'], TicketJourneyPerformance.detail_sort_options('delivered_weight', nil, nil)
    assert_equal ['id', 'asc'], TicketJourneyPerformance.detail_sort_options('missing_due', nil, nil)
    assert_equal ['due', 'asc'], TicketJourneyPerformance.detail_sort_options('due', 'invalid', 'desc')
    assert_equal ['subject', 'asc'], TicketJourneyPerformance.detail_sort_options('open', 'subject', 'invalid')
  end

  test 'projects remain grouped with nulls last and stable ID ties in either direction' do
    date = Date.new(2026, 10, 14)
    rows = [
      { id: 1, project_id: 2, project_name: 'Zebra', due: date - 5 },
      { id: 2, project_id: 1, project_name: 'Alpha', due: nil },
      { id: 4, project_id: 1, project_name: 'Alpha', due: date },
      { id: 3, project_id: 1, project_name: 'Alpha', due: date },
      { id: 5, project_id: 1, project_name: 'Alpha', due: date - 1 }
    ]
    assert_equal [5, 3, 4, 2, 1], TicketJourneyPerformance.sort_details(rows, 'due', 'asc', group_by: 'project').map { |r| r[:id] }
    assert_equal [3, 4, 5, 2, 1], TicketJourneyPerformance.sort_details(rows, 'due', 'desc', group_by: 'project').map { |r| r[:id] }
    # With no grouping, project boundaries must not override the selected sort.
    assert_equal [1, 5, 3, 4, 2], TicketJourneyPerformance.sort_details(rows, 'due', 'asc').map { |r| r[:id] }
    assert_equal [3, 4, 5, 1, 2], TicketJourneyPerformance.sort_details(rows, 'due', 'desc').map { |r| r[:id] }
  end

  test 'optional historical status groups stay contiguous before pagination' do
    rows = (1..105).map do |id|
      { id: id, status_name: id.odd? ? 'Review' : 'Pending', project_id: id % 3, weight: id }
    end
    grouped = TicketJourneyPerformance.sort_details(rows, 'weight', 'desc', group_by: 'status')
    assert_equal 104, grouped.first[:id]
    assert_equal 'Pending', grouped[51][:status_name]
    assert_equal 'Review', grouped[52][:status_name]
    assert_equal [9, 7, 5, 3, 1], grouped.slice(100, 100).map { |row| row[:id] }
    assert_nil TicketJourneyPerformance.detail_group_key(rows.first, 'invalid')
  end

  test 'all rows are sorted before a page is selected' do
    rows = (1..105).map { |id| { id: id, project_id: 1, project_name: 'Project', weight: id, missing_weight: false } }
    sorted = TicketJourneyPerformance.sort_details(rows, 'weight', 'desc')
    assert_equal 105, sorted.first[:id]
    assert_equal [5, 4, 3, 2, 1], sorted.slice(100, 100).map { |r| r[:id] }
    rows.last[:missing_weight] = true
    assert_equal 105, TicketJourneyPerformance.sort_details(rows, 'weight', 'desc').last[:id]
  end
end
