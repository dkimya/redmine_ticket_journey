require File.expand_path('../test_helper', __dir__)

class TicketJourneyCarryOverTest < ActiveSupport::TestCase
  Sprint = Struct.new(:start_date, :due_date)
  Ticket = Struct.new(:id, :due_date, :status)
  Status = Struct.new(:name)

  setup do
    @controller = TicketJourneyController.new
    @sprint = Sprint.new(Date.new(2026, 9, 24), Date.new(2026, 9, 30))
  end

  test 'carry-over depends on the current due date strictly before sprint start' do
    issue = Ticket.new(101, Date.new(2026, 9, 23), Status.new('In Progress'))
    issue.expects(:custom_value_for).never
    assert @controller.send(:carry_over_sprint_issue?, @sprint, issue)

    issue.due_date = @sprint.start_date
    assert_not @controller.send(:carry_over_sprint_issue?, @sprint, issue)

    issue.due_date = Date.new(2026, 10, 1)
    assert_not @controller.send(:carry_over_sprint_issue?, @sprint, issue)

    issue.due_date = Date.new(2026, 9, 22)
    assert @controller.send(:carry_over_sprint_issue?, @sprint, issue)
  end

  test 'missing dates never fall back to original sprint' do
    issue = Ticket.new(101, nil, Status.new('In Progress'))
    issue.expects(:custom_value_for).never
    assert_not @controller.send(:carry_over_sprint_issue?, @sprint, issue)

    issue.due_date = Date.new(2026, 9, 23)
    @sprint.start_date = nil
    assert_not @controller.send(:carry_over_sprint_issue?, @sprint, issue)
    assert_not @controller.send(:carry_over_sprint_issue?, nil, issue)
  end

  test 'totals owner counts and flags use dates and technical debt excludes completed carry-over' do
    issues = [
      Ticket.new(101, Date.new(2026, 9, 23), Status.new('In Progress')),
      Ticket.new(102, Date.new(2026, 9, 22), Status.new('Done / Closed')),
      Ticket.new(103, Date.new(2026, 9, 24), Status.new('In Progress')),
      Ticket.new(104, nil, Status.new('In Progress'))
    ]
    @controller.stubs(:sprint_delivery_overdue?).returns(false)
    @controller.stubs(:sprint_blocked_duration_days).returns(0)
    @controller.stubs(:ticket_owner_info).returns(['7', 'Owner'])
    issues.each { |issue| issue.stubs(:custom_value_for).returns(nil) }

    totals = @controller.send(:sprint_delivery_totals, @sprint, issues)
    assert_equal 2, totals[:carry_over]
    assert_equal 0.5, totals[:carry_over_rate]
    assert_equal 1, totals[:technical_debt]
    assert_equal 2, totals[:current_scope]

    owners = @controller.send(:sprint_delivery_owner_rows, @sprint, issues)
    assert_equal 2, owners.first[:carry_over]

    rows = @controller.send(:sprint_delivery_issue_rows, @sprint, issues)
    assert_equal [101, 102], rows.select { |row| row[:flags].include?('Carry-over') }.map { |row| row[:issue].id }

    composition = @controller.send(:planning_composition_rows, @sprint, issues, [issues[2], issues[3]], issues.first(2))
    assert_equal 'Carry-over by Due Date', composition[1][:item]
    assert_equal [101, 102], composition[1][:issue_ids]
  end
end
