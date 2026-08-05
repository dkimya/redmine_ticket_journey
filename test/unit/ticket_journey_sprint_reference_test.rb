require File.expand_path('../test_helper', __dir__)

class TicketJourneySprintReferenceTest < ActiveSupport::TestCase
  Sprint = Struct.new(:id, :subject, :start_date, :due_date)

  setup do
    @controller = TicketJourneyController.new
    @sprint = Sprint.new(13_932, 'FMS- Sprint August-1', Date.new(2026, 8, 1), Date.new(2026, 8, 10))
  end

  test 'coded original sprint matches the selected calendar sprint alias' do
    assert sprint_reference_matches?('FMS-26-AUG-W1')
  end

  test 'different month remains a carry-over' do
    assert_not sprint_reference_matches?('FMS-26-JUL-W1')
  end

  test 'different week remains a carry-over' do
    assert_not sprint_reference_matches?('FMS-26-AUG-W2')
  end

  test 'different project prefix remains a carry-over' do
    assert_not sprint_reference_matches?('PMO-26-AUG-W1')
  end

  test 'different year remains a carry-over' do
    assert_not sprint_reference_matches?('FMS-25-AUG-W1')
  end

  private

  def sprint_reference_matches?(reference)
    @controller.send(:sprint_reference_matches?, @sprint, reference)
  end
end
