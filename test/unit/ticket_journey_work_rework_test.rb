require File.expand_path('../test_helper', __dir__)

class TicketJourneyWorkReworkTest < ActiveSupport::TestCase
  test 'first review and final check after a QA return are work until repeated after another return' do
    first = Date.new(2026, 10, 1)
    statuses = %w[In\ Progress Feedback Returned Review Final\ Check].each_with_index.to_h do |name, index|
      [(index + 1).to_s, Struct.new(:name).new(name)]
    end
    tracker = Struct.new(:name).new('Bug')
    issue = Struct.new(:created_on, :status_id, :tracker).new(first.in_time_zone, 5, tracker)
    transitions = [[0, 1, 2], [1, 2, 3], [2, 3, 1], [4, 1, 2], [6, 2, 4],
                   [8, 4, 3], [9, 3, 4], [11, 4, 5]]
    history = transitions.each_with_index.map do |(offset, from, to), id|
      detail = TicketJourneyPerformance::HistoryDetail.new('attr', 'status_id', from.to_s, to.to_s, id)
      TicketJourneyPerformance::HistoryJournal.new(id, (first + offset).in_time_zone + 12.hours, [detail])
    end
    hours = [1, 3, 5, 7, 10, 12].map { |offset| [first + offset, 2.0] }

    classified = TicketJourneyWorkRework.classify(issue, history, statuses, first + 12, hours)

    assert_equal [[:unclassified, :unknown], [:development, :rework], [:test, :rework],
                  [:development, :work], [:development, :rework], [:test, :work]],
                 classified.map { |_day, phase, kind, _amount| [phase, kind] }
    summary = TicketJourneyWorkRework.summary
    TicketJourneyWorkRework.add!(summary, { weight: 4.0 }, classified, [], first + 12, true)
    assert_equal 12.0, TicketJourneyWorkRework.total(summary)
    assert_equal 60.0, TicketJourneyWorkRework.rework_percent(summary)
  end
end
