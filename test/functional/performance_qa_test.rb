require File.expand_path('../test_helper', __dir__)

class PerformanceQaTest < ActionController::TestCase
  tests PerformanceDashboardController
  fixtures :all

  setup do
    @request.session[:user_id] = 1
    @issue = Issue.find(1)
    @project = @issue.project
    @project.enabled_module_names |= ['ticket_journey']
    @issue.tracker.update!(name: 'Bug')
    @params = { project_id: @project.identifier, issue_id: @issue.id, journal_detail_id: 101,
                as_of: Date.current.iso8601, decision: 'exclude', reason: 'Reviewed and found invalid' }
  end

  test 'QA navigation stays scan free until Apply' do
    TicketJourneyQaReport.expects(:new).never
    get :index, params: { project_id: @project.identifier, tab: 'qa' }
    assert_response :success
    assert_select '.performance-tabs a[aria-current="page"]', text: 'QA / Testers'
  end

  test 'exclusion and reinstatement keep both decisions and leave the journal untouched' do
    field_id = TicketJourneyController::RETURN_REASON_CF_ID
    Issue.any_instance.stubs(:visible_custom_field_values).returns([stub(custom_field: stub(id: field_id))])
    TicketJourneyPerformance.stubs(:history_for).returns({})
    TicketJourneyQaReport.stubs(:changes).returns([
      { id: 100, at: 2.days.ago, from: 'Feedback', to: 'Review', user_id: 2 },
      { id: 101, at: 1.day.ago, from: 'Final Check', to: 'Returned', reason: 'False QA Pass' }
    ])
    assert_no_difference 'Journal.count' do
      assert_difference 'TicketJourneyQaCorrection.count', 2 do
        post :qa_correction, params: @params
        assert_response :see_other
        post :qa_correction, params: @params.merge(decision: 'reinstate', reason: 'Second review')
        assert_response :see_other
      end
    end
    entries = TicketJourneyQaCorrection.where(issue_id: @issue.id, journal_detail_id: 101).order(:id)
    assert_equal [true, false], entries.pluck(:excluded)
    assert_equal [1, 1], entries.pluck(:user_id)
  end

  test 'a denied correction does not create an audit entry' do
    @controller.stubs(:qa_correction_allowed?).returns(false)
    assert_no_difference 'TicketJourneyQaCorrection.count' do
      post :qa_correction, params: @params
    end
    assert_response :forbidden
  end
end
