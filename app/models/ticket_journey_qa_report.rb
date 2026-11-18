class TicketJourneyQaReport
  GATES = ['Feedback', 'Final Check'].freeze
  FALSE_PASS_SOURCES = ['Review', 'Ready to Merge', 'Final Check'].freeze
  COMPLETED = ['Done / Closed', 'Done', 'Closed'].freeze
  REJECTED_BUGS = %w[Rejected Duplicate].freeze
  FALSE_PASS_REASON = 'False QA Pass'.freeze
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

  attr_reader :queue, :bugs, :returns, :return_reasons, :passes, :tested,
              :time, :time_unavailable, :activity_configured, :detected_field

  def initialize(project_ids:, user:, finish:, start: nil)
    @user, @start, @finish = user, start, finish
    @cutoff = finish.in_time_zone.end_of_day
    @statuses = IssueStatus.all.index_by { |status| status.id.to_s }
    @calendar = TicketJourney::WorkingCalendar.new(Setting.plugin_redmine_ticket_journey)
    fields = IssueCustomField.where(name: DETECTED_BY).limit(2).to_a
    @detected_field = fields.first if fields.one?
    @issues = Issue.visible(user).where(project_id: project_ids)
      .joins(:tracker).where(trackers: { name: TicketJourneyPerformance::TRACKERS })
    @queue, @bugs, @returns, @passes = [], [], [], []
    @return_reasons = Hash.new(0)
    @tested = []
    @time = { work: 0.0, rework: 0.0 }
    @time_unavailable = 0
    @activity_configured = TimeEntryActivity.exists?(name: TEST_ACTIVITY)
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

  private

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
      next unless in_scope?(status, recorded)

      [issue, status, recorded]
    end
    time_rows = activity_configured ? TicketJourneyPerformanceTime.hours_for(selected.map { |issue, _, _| issue.id }, @finish, by_activity: true) : {}
    escape_ids = selected.filter_map do |issue, _, _|
      issue.id if issue.tracker.name == 'Bug' && field_values(fields, issue)[TicketJourneyController::BUG_SOURCE_CF_ID] == 'Test Escape'
    end
    sources = escape_sources(escape_ids)
    selected.each do |issue, status, recorded|
      values = field_values(fields, issue)
      weight = TicketJourney::WorkingCalendar.positive_number(values[70])
      row = { issue: issue, status: status, weight: weight }

      if !@start && GATES.include?(status)
        entered_at = recorded.last&.fetch(:at) || issue.created_on
        @queue << row.merge(age: @calendar.age(entered_at.in_time_zone.to_date, @finish))
      end
      if recorded.any? { |change| change[:from] == 'Feedback' && change[:to] == 'Review' }
        @passes << row
      end
      verdicts = recorded.filter_map do |change|
        if change[:from] == 'Feedback' && %w[Review Returned].include?(change[:to])
          ['QA', change[:user_id]]
        elsif change[:from] == 'Final Check' && (COMPLETED.include?(change[:to]) || change[:to] == 'Returned')
          ['QA-L2', change[:user_id]]
        end
      end.uniq
      @tested << row.merge(verdicts: verdicts) if verdicts.any?
      reason_visible = values.key?(reason_id)
      recorded.each do |change|
        next unless change[:to] == 'Returned'

        label = change[:reason] if reason_visible
        @return_reasons[label || 'Reason unavailable'] += 1
      end
      self.class.false_passes(recorded, reason_visible: reason_visible).each do |event|
        audit = corrections.fetch([issue.id, event[:id]], [])
        @returns << row.merge(event: event, audit: audit, points: penalty(weight, event, audit))
      end
      add_bug(row, values, sources[issue.id]) if issue.tracker.name == 'Bug'
      if @user.allowed_to?(:view_time_entries, issue.project)
        first_return = recorded.find { |change| change[:to] == 'Returned' }
        hours = self.class.test_time(time_rows.fetch(issue.id, []), first_return&.fetch(:at))
        @time.merge!(hours) { |_key, total, extra| total + extra }
      else
        @time_unavailable += 1
      end
    end
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

    audit.last&.excluded? ? 0 : -2 * weight
  end

  def add_bug(row, values, escape_actor)
    detected_by = values[detected_field&.id]
    escape = values[TicketJourneyController::BUG_SOURCE_CF_ID] == 'Test Escape'
    eligible = !REJECTED_BUGS.include?(row[:status])
    weight = row[:weight]
    @bugs << row.merge(detected_by: detected_by, finder_id: row[:issue].author_id,
      credit: eligible && detected_by == 'QA' && weight ? weight : nil,
      escape: escape, escape_actor: escape_actor,
      escape_points: eligible && escape && escape_actor && weight ? -2 * weight : nil)
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
