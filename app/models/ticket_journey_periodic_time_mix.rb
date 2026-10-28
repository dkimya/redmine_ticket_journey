# Work-date activity/user evidence. Package cost uses all visible contributors;
# personal time uses selected booked users. Archived contributors are separate.
# These overlapping scopes are never added together.
class TicketJourneyPeriodicTimeMix
  def self.calculate(rows, owners, first_day, last_day, development_ids, available: true)
    packages = owners.to_h do |entry|
      report = entry[:report][:tickets]
      [entry[:owner].id.to_s, { expected: report[:sets]['expected'].map { |row| row[:id] }.to_set,
        completed: report[:sets]['completed'].map { |row| row[:id] }.to_set }]
    end
    empty = { expected: Set.new, completed: Set.new }
    personal, package, archived = [], [], []
    rows.each do |row|
      next unless row[:time_allowed]
      owner_package = packages.fetch(row[:owner_id], empty)
      row.fetch(:mix_records, []).each do |entry|
        next unless entry[:day].between?(first_day, last_day)
        base = entry.merge(issue_id: row[:id], subject: row[:subject], tracker: row[:tracker_name],
          project: row[:project_name], package_owner: row[:owner_id], current_status: TicketJourneyPeriodicTickets.current_status(row))
        if packages.key?(entry[:user_id])
          own = packages.fetch(entry[:user_id])
          personal << base.merge(category: TicketJourneyPeriodicTime.work_category(row, own[:expected], own[:completed]))
        end
        if row[:owner_visible] && owner_package[:expected].include?(row[:id])
          package << base.merge(category: TicketJourneyPeriodicTime.work_category(row, owner_package[:expected], owner_package[:completed]))
        end
        if row[:owner_visible] && packages.key?(row[:owner_id]) && TicketJourneyPeriodicTickets.current_status(row) == 'Archived'
          archived << base.merge(category: 'archived')
        end
      end
    end
    { personal: personal, package: package, archived: archived, development_ids: development_ids, available: available,
      personal_summary: summarize(personal, development_ids, available: available), package_summary: summarize(package, development_ids, available: available) }
  end

  def self.summarize(records, development_ids, available: true)
    known = TicketJourneyPeriodicTime.finite_sum(records.sum { |entry| entry[:hours].to_f })
    total = !available || records.any? { |entry| entry[:hours].nil? } ? nil : known
    development = records.select { |entry| development_ids.include?(entry[:activity_id]) }
    development_hours = if development_ids.any? && development.none? { |entry| entry[:hours].nil? }
      TicketJourneyPeriodicTime.finite_sum(development.sum { |entry| entry[:hours] })
    end
    owner_hours = records.select { |entry| entry[:user_id] == entry[:package_owner] }
    own_total = owner_hours.any? { |entry| entry[:hours].nil? } ? nil : TicketJourneyPeriodicTime.finite_sum(owner_hours.sum { |entry| entry[:hours] })
    { total: total, known: known, invalid: records.sum { |entry| entry[:invalid_count].to_i },
      development: development_hours,
      development_share: total && total.positive? && development_hours ? development_hours * 100.0 / total : nil,
      owner_share: total && total.positive? && own_total ? own_total * 100.0 / total : nil,
      tickets: records.map { |entry| entry[:issue_id] }.uniq.size }
  end

  def self.group(records, key, development_ids, available: true)
    records.group_by { |entry| entry[key] }.sort_by { |value, _entries| value.to_s }.map do |value, entries|
      { key: value, report: summarize(entries, development_ids, available: available), records: entries }
    end
  end
end
