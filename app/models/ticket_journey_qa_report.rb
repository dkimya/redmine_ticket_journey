class TicketJourneyQaReport
  GATES = ['Feedback', 'Final Check'].freeze
  GATE_ROLES = { 'Feedback' => 'QA', 'Final Check' => 'QA-L2' }.freeze
  FALSE_PASS_SOURCES = ['Review', 'Ready to Merge', 'Final Check'].freeze
  COMPLETED = ['Done / Closed', 'Done', 'Closed'].freeze
  REJECTED_BUGS = %w[Rejected Duplicate].freeze
  FALSE_PASS_REASON = 'False QA Pass'.freeze
  BUG_CREDIT_WEIGHT = 1
  FALSE_PASS_WEIGHT = -1
  TEST_ESCAPE_WEIGHT = -2
  TEST_ACTIVITY = 'Test / QA / Feedback'.freeze
  DETECTED_BY = 'Detected By'.freeze

  def self.changes(history, statuses)
    history.flat_map do |journal|
      reason = journal.details.reverse.find do |detail|
        detail.property == 'cf' && detail.prop_key == TicketJourneyController::RETURN_REASON_CF_ID.to_s
      end
      journal.details.filter_map do |detail|
        next unless detail.property == 'attr' && detail.prop_key == 'status_id'

        { id: detail.id, at: journal.created_on, user_id: journal.user_id,
          from: statuses[detail.old_value.to_s]&.name&.strip, to: statuses[detail.value.to_s]&.name&.strip,
          reason: reason&.value.to_s.strip.presence }
      end
    end
  end

  def self.false_passes(changes, reason_visible:)
    pass = nil
    changes.filter_map do |change|
      if change[:from] == 'Feedback' && change[:to] == 'Review'
        pass = change
        next
      end
      pass = nil if change[:to] == 'Feedback' || COMPLETED.include?(change[:to])
      next unless change[:to] == 'Returned'

      previous_pass, pass = pass, nil
      next unless previous_pass && FALSE_PASS_SOURCES.include?(change[:from])

      reason = change[:reason] if reason_visible
      next if reason && reason != FALSE_PASS_REASON

      change.merge(reason: reason, pass: previous_pass)
    end
  end

  def self.status_at(issue, changes, cutoff, statuses)
    later = changes.find { |change| change[:at] > cutoff }
    later ? later[:from] : statuses[issue.status_id.to_s]&.name&.strip
  end

  def self.test_time(entries, first_return_at)
    return_day = first_return_at&.in_time_zone&.to_date
    entries.each_with_object({ work: 0.0, rework: 0.0 }) do |(day, hours, activity), totals|
      next unless activity == TEST_ACTIVITY

      totals[return_day && day > return_day ? :rework : :work] += hours
    end
  end

  # An observed entry is required for elapsed time. A verdict can still count
  # when the ticket's history has no corresponding entry into the gate.
  def self.gate_history(changes)
    entered = {}
    verdicts = changes.filter_map do |change|
      from, to, at = change.values_at(:from, :to, :at)
      next if from == to

      started = entered.delete(from)
      entered[to] = at if GATES.include?(to)
      passed = (from == 'Feedback' && to == 'Review') || (from == 'Final Check' && COMPLETED.include?(to))
      next unless GATES.include?(from) && (passed || to == 'Returned')

      { role: GATE_ROLES.fetch(from), actor: change[:user_id], outcome: passed ? :passed : :returned,
        days: calendar_days(started, at) }
    end
    [verdicts, entered]
  end

  def self.calendar_days(started, finish)
    (finish - started) / 86400.0 if started && finish >= started
  end

  attr_reader :queue, :bugs, :returns, :return_reasons, :passes, :tested,
              :time, :time_unavailable, :activity_configured, :detected_field, :dashboard_rows

  def initialize(project_ids:, user:, finish:, start: nil, tester_ids: [], tester_roles: nil)
    @user, @start, @finish = user, start, finish
    @tester_ids = tester_ids.to_set
    @tester_roles = tester_roles
    @cutoff = finish.in_time_zone.end_of_day
    @statuses = IssueStatus.all.index_by { |status| status.id.to_s }
    fields = IssueCustomField.where(name: DETECTED_BY).limit(2).to_a
    @detected_field = fields.first if fields.one?
    @issues = Issue.visible(user).where(project_id: project_ids)
      .joins(:tracker).where(trackers: { name: TicketJourneyPerformance::TRACKERS })
    @queue, @bugs, @returns, @passes = [], [], [], []
    @return_reasons = Hash.new(0)
    @tested = []
    @dashboard_rows = []
    @time = { work: 0.0, rework: 0.0 }
    @tester_time = Hash.new { |hash, id| hash[id] = { work: 0.0, rework: 0.0 } }
    @time_unavailable = 0
    @activity_ids = TimeEntryActivity.where(name: TEST_ACTIVITY).pluck(:id, :name).filter_map do |id, name|
      id if name == TEST_ACTIVITY
    end
    @activity_configured = @activity_ids.any?
  end

  def calculate
    Issue.uncached do
      columns = Issue.column_names.reject { |name| name == 'description' }.map { |name| "issues.#{name}" }
      @issues.where('issues.created_on <= ?', @cutoff).select(columns).preload(:project, :tracker)
        .find_in_batches(batch_size: TicketJourneyPerformance::BATCH_SIZE) do |batch|
        scan(batch)
      end
    end
    self
  end

  def self.correction_history(ids)
    TicketJourneyQaCorrection.where(issue_id: ids).order(:id).group_by { |record| [record.issue_id, record.journal_detail_id] }
  end

  def tester_results(ids)
    results = ids.index_with do |id|
      @tester_time.fetch(id, { work: 0.0, rework: 0.0 }).merge(passed: 0, caught: 0,
        false_passes: 0, escapes: 0, points: 0)
    end
    @passes.each do |row|
      row[:actors].each { |id| results[id][:passed] += 1 if results.key?(id) }
    end
    @bugs.each do |row|
      next if REJECTED_BUGS.include?(row[:status])

      finder = results[row[:finder_id]]
      if row[:qa_find] && finder
        finder[:caught] += 1
        finder[:points] += row[:credit].to_f
      end
      closer = results[row[:escape_actor]]
      if row[:escape] && closer
        closer[:escapes] += 1
        closer[:points] += row[:escape_points].to_f
      end
    end
    @returns.each do |row|
      event = row[:event]
      tester = results[event[:pass][:user_id]]
      next unless event[:reason] == FALSE_PASS_REASON && tester

      tester[:false_passes] += 1
      tester[:points] += row[:points].to_f
    end
    results
  end

  private

  def tester_in_scope?(id)
    @tester_ids.empty? || @tester_ids.include?(id)
  end

  def testing_entries(ids)
    return {} if !activity_configured || ids.empty?

    scope = TimeEntry.visible(@user).where(issue_id: ids, activity_id: @activity_ids)
      .where('time_entries.spent_on <= ? AND time_entries.hours >= 0 AND time_entries.hours <= ?', @finish, Float::MAX)
    scope = scope.where(user_id: @tester_ids.to_a) if @tester_ids.any?
    entries = Hash.new { |hash, id| hash[id] = {} }
    scope.group(:issue_id, :user_id, :spent_on).sum(:hours).each do |(issue_id, user_id, day), hours|
      next unless hours.to_f.finite?

      (entries[issue_id][user_id] ||= []) << [day.to_date, hours.to_f, TEST_ACTIVITY]
    end
    entries
  end

  def scan(batch)
    ids = batch.map(&:id)
    history = TicketJourneyPerformance.history_for(ids, @finish, include_return_reason: true)
    reason_id = TicketJourneyController::RETURN_REASON_CF_ID
    fields = TicketJourneyPerformance.batch_field_values(batch,
      field_ids: [reason_id, TicketJourneyController::BUG_SOURCE_CF_ID, 70, detected_field&.id].compact)
    corrections = self.class.correction_history(ids)
    selected = batch.filter_map do |issue|
      changes = self.class.changes(history.fetch(issue.id, []), @statuses)
      status = self.class.status_at(issue, changes, @cutoff, @statuses)
      recorded = changes.take_while { |change| change[:at] <= @cutoff }
      unless in_scope?(status, recorded)
        if @start && GATES.include?(status)
          weight = TicketJourney::WorkingCalendar.positive_number(field_values(fields, issue)[70])
          _, entered = self.class.gate_history(recorded)
          add_queue_ticket(issue, status, weight, entered[status])
        end
        next
      end

      [issue, status, recorded]
    end
    time_rows = testing_entries(selected.map { |issue, _, _| issue.id })
    escape_ids = selected.filter_map do |issue, _, _|
      issue.id if issue.tracker.name == 'Bug' && field_values(fields, issue)[TicketJourneyController::BUG_SOURCE_CF_ID] == 'Test Escape'
    end
    sources = escape_sources(escape_ids)
    selected.each do |issue, status, recorded|
      values = field_values(fields, issue)
      weight = TicketJourney::WorkingCalendar.positive_number(values[70])
      workflow_gates, entered = self.class.gate_history(recorded)
      gates = workflow_gates.select do |gate|
        tester_in_scope?(gate[:actor]) &&
          (@tester_ids.empty? || !@tester_roles || @tester_roles.fetch(gate[:actor], []).include?(gate[:role]))
      end
      completion = recorded.reverse.find { |event| COMPLETED.include?(event[:to]) && !COMPLETED.include?(event[:from]) }
      time_allowed = @user.allowed_to?(:view_time_entries, issue.project)
      first_return = recorded.find { |change| change[:to] == 'Returned' }
      testing = if time_allowed
        time_rows.fetch(issue.id, {}).transform_values { |entries| self.class.test_time(entries, first_return&.fetch(:at)) }
      else
        {}
      end
      row = { issue: issue, status: status, weight: weight, gates: gates, workflow_gates: workflow_gates, testing: testing,
        completed_on: completion&.fetch(:at)&.in_time_zone&.to_date }
      @dashboard_rows << row

      if !@start && GATES.include?(status)
        add_queue_ticket(issue, status, weight, entered[status])
      end
      pass_actors = gates.filter_map { |gate| gate[:actor] if gate[:role] == 'QA' && gate[:outcome] == :passed }.uniq
      @passes << row.merge(actors: pass_actors) if pass_actors.any?
      verdicts = gates.map { |gate| gate.values_at(:role, :actor) }.uniq
      @tested << row.merge(verdicts: verdicts) if verdicts.any?
      reason_visible = values.key?(reason_id)
      recorded.each do |change|
        next unless change[:to] == 'Returned'

        label = change[:reason] if reason_visible
        @return_reasons[label || 'Reason unavailable'] += 1
      end
      self.class.false_passes(recorded, reason_visible: reason_visible).each do |event|
        next unless tester_in_scope?(event[:pass][:user_id])

        audit = corrections.fetch([issue.id, event[:id]], [])
        @returns << row.merge(event: event, audit: audit, points: penalty(weight, event, audit))
      end
      add_bug(row, values, sources[issue.id]) if issue.tracker.name == 'Bug'
      if time_allowed
        testing.each do |actor, hours|
          @time.merge!(hours) { |_key, total, extra| total + extra }
          @tester_time[actor].merge!(hours) { |_key, total, extra| total + extra }
        end
      else
        @time_unavailable += 1
      end
    end
  end

  def add_queue_ticket(issue, status, weight, entered_at)
    due = issue.due_date
    @queue << { issue: issue, status: status, weight: weight, age: self.class.calendar_days(entered_at, @cutoff),
      close_to_due: due && due.between?(@finish, @finish + 3) }
  end

  def field_values(fields, issue)
    fields.fetch(issue.id).to_h { |field| [field.custom_field.id, field.value.to_s.strip.presence] }
  end

  def in_scope?(status, recorded)
    return false if status.nil?

    if @start
      completion = recorded.reverse.find { |change| COMPLETED.include?(change[:to]) && !COMPLETED.include?(change[:from]) }
      COMPLETED.include?(status) && completion && completion[:at].in_time_zone.to_date >= @start
    else
      @statuses.values.none? { |entry| entry.name.strip == status && entry.is_closed? }
    end
  end

  def penalty(weight, event, audit)
    return if !weight || !event[:reason] || !event[:pass][:user_id]

    audit.last&.excluded? ? 0 : FALSE_PASS_WEIGHT * weight
  end

  def add_bug(row, values, escape_actor)
    detected_by = values[detected_field&.id]
    finder = row[:issue].author_id
    qa_find = detected_by == 'QA' && tester_in_scope?(finder)
    escape = values[TicketJourneyController::BUG_SOURCE_CF_ID] == 'Test Escape' && tester_in_scope?(escape_actor)
    return if @tester_ids.any? && !qa_find && !escape

    eligible = !REJECTED_BUGS.include?(row[:status])
    weight = row[:weight]
    @bugs << row.merge(detected_by: detected_by, finder_id: qa_find ? finder : nil, qa_find: qa_find,
      credit: eligible && qa_find && weight ? BUG_CREDIT_WEIGHT * weight : nil,
      escape: escape, escape_actor: escape ? escape_actor : nil,
      escape_points: eligible && escape && escape_actor && weight ? TEST_ESCAPE_WEIGHT * weight : nil)
  end

  def escape_sources(ids)
    return {} if ids.empty?

    links = Hash.new { |hash, id| hash[id] = [] }
    relations = IssueRelation.where(relation_type: 'relates')
    relations.where(issue_from_id: ids).or(relations.where(issue_to_id: ids)).pluck(:issue_from_id, :issue_to_id).each do |from, to|
      links[from] << to if ids.include?(from)
      links[to] << from if ids.include?(to)
    end
    candidates = links.filter_map { |id, related| [id, related.first] if related.uniq.one? }.to_h
    sources = Issue.visible(@user).where(id: candidates.values).index_by(&:id)
    dates = @issues.where(id: candidates.keys).pluck(:id, :created_on).to_h
    history = TicketJourneyPerformance.history_for(sources.keys, @finish)
    candidates.filter_map do |bug, source_id|
      source = sources[source_id]
      next unless source && dates[bug] && source.created_on <= dates[bug]

      changes = self.class.changes(history.fetch(source_id, []), @statuses)
      next unless COMPLETED.include?(self.class.status_at(source, changes, dates[bug], @statuses))

      closure = changes.take_while { |change| change[:at] <= dates[bug] }.reverse.find do |change|
        COMPLETED.include?(change[:to]) && !COMPLETED.include?(change[:from])
      end
      [bug, closure[:user_id]] if closure && closure[:from] == 'Final Check' && closure[:user_id]
    end.to_h
  end
end
