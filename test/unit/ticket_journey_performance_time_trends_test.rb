require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceTimeTrendsTest < ActiveSupport::TestCase
  def snapshot(**values)
    { id: 1, owner_id: '1', open: true, status_name: 'In Progress', done: false,
      delivered_at: nil, weight: 8.0, missing_weight: false }.merge(values)
  end

  test 'weekly average includes zero log weeks and uses five completed months across leap year' do
    owners = { '1' => TicketJourneyPerformanceTimeTrends.points(Date.new(2024, 3, 15)),
      '2' => TicketJourneyPerformanceTimeTrends.points(Date.new(2024, 3, 15)) }
    assert_equal [10, 11, 12, 1, 2], owners['1'].map { |point| point[:date].month }
    TicketJourneyPerformanceTimeTrends.add_logged_hours!(owners, {
      [1, Date.new(2024, 2, 1)] => 10.0, [1, Date.new(2024, 2, 29)] => 19.0,
      [1, Date.new(2024, 3, 1)] => 100.0, [2, Date.new(2024, 2, 2)] => 58.0,
      [3, Date.new(2024, 2, 1)] => 100.0
    })
    owners.each_value { |points| TicketJourneyPerformanceTimeTrends.finish!(points, time_visible: true) }
    assert_equal 29.0, owners['1'].last[:logged_hours]
    assert_in_delta 7.0, owners['1'].last[:weekly_average], 0.000001
    assert_in_delta 14.0, owners['2'].last[:weekly_average], 0.000001
    assert_equal 0.0, owners['1'].first[:weekly_average]
    assert_nil owners['1'].first[:open_average]
    TicketJourneyPerformanceTimeTrends.finish!(owners['1'], time_visible: false)
    assert_nil owners['1'].last[:weekly_average]
  end

  test 'open average includes Ongoing and zero hour tickets but not excluded statuses' do
    point = TicketJourneyPerformanceTimeTrends.points(Date.new(2026, 10, 21)).last
    TicketJourneyPerformanceTimeTrends.accumulate!(point, snapshot, ticket_hours: 100.0, owner_hours: 6.0)
    TicketJourneyPerformanceTimeTrends.accumulate!(point, snapshot(id: 2, status_name: 'Ongoing'), ticket_hours: 20.0, owner_hours: 0.0)
    %w[New On-Hold Archived].each do |status|
      TicketJourneyPerformanceTimeTrends.accumulate!(point, snapshot(status_name: status), ticket_hours: 100.0, owner_hours: 100.0)
    end
    TicketJourneyPerformanceTimeTrends.finish!([point], time_visible: true)
    assert_equal 2, point[:open_count]
    assert_equal 6.0, point[:open_owner_hours]
    assert_equal 3.0, point[:open_average]
    TicketJourneyPerformanceTimeTrends.accumulate!(point, snapshot(id: 3), ticket_hours: nil, owner_hours: nil)
    TicketJourneyPerformanceTimeTrends.finish!([point], time_visible: true)
    assert_equal 3, point[:open_count]
    assert_equal 1, point[:open_unavailable]
    assert_nil point[:open_average]
  end

  test 'productivity pairs current delivered weight with all contributor hours' do
    point = TicketJourneyPerformanceTimeTrends.points(Date.new(2026, 10, 21)).last
    delivered = snapshot(open: false, done: true, status_name: 'Done / Closed', delivered_at: point[:date])
    TicketJourneyPerformanceTimeTrends.accumulate!(point, delivered, ticket_hours: 4.0, owner_hours: 1.0)
    TicketJourneyPerformanceTimeTrends.accumulate!(point, delivered.merge(id: 2, missing_weight: true), ticket_hours: 100.0, owner_hours: 100.0)
    TicketJourneyPerformanceTimeTrends.accumulate!(point, delivered.merge(id: 3), ticket_hours: nil, owner_hours: nil)
    TicketJourneyPerformanceTimeTrends.accumulate!(point, delivered.merge(id: 4, delivered_at: point[:date] + 1), ticket_hours: 10.0, owner_hours: 1.0)
    TicketJourneyPerformanceTimeTrends.finish!([point], time_visible: true)
    assert_equal 1, point[:count]
    assert_equal 2, point[:excluded]
    assert_equal 2.0, point[:productivity]
    assert_equal 0, point[:open_count]
  end
end
