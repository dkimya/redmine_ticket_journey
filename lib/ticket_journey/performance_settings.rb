module TicketJourney
  module PerformanceSettings
    DEFAULT_DELIVERY_TARGET = 90.0
    PERIODIC_DEFAULTS = {
      'performance_periodic_dtc_target' => 7.0,
      'performance_periodic_priority_dtc_target' => 3.0,
      # Retain the stored key for existing installations and explicit overrides.
      'performance_periodic_owner_share' => 90.0
    }.freeze

    def self.parse_target(value)
      number = Float(value.to_s, exception: false)
      number if number && number.finite? && number.between?(0, 100)
    end

    def self.delivery_target(settings)
      parse_target(settings['performance_delivery_target']) || DEFAULT_DELIVERY_TARGET
    end

    def self.live_owner_share(settings)
      parse_target(settings['performance_live_owner_share']) || 90.0
    end

    def self.time_threshold(settings, key)
      parse_target(settings[key]) || 10.0
    end

    def self.periodic_target(settings, key)
      value = settings[key].blank? ? PERIODIC_DEFAULTS[key] : settings[key]
      return parse_target(value) if key == 'performance_periodic_owner_share'
      number = Float(value.to_s, exception: false)
      number if number && number.finite? && number >= 0
    end

    # Classification is now a confirmed business rule, not a configurable guess.
    # Include project-specific and inactive activities used by historical entries.
    def self.development_activities
      TimeEntryActivity.where(name: 'Development')
    end

    def self.included(base)
      base.validate :validate_performance_delivery_target
      base.validate :validate_performance_time_settings
    end

    private

    def validate_performance_time_settings
      return unless name == 'plugin_redmine_ticket_journey' && value.is_a?(Hash)
      config = value
      activity_ids = Array(config['performance_periodic_development_activity_ids']).map(&:to_s).reject(&:blank?).uniq
      if activity_ids.any? && (activity_ids.any? { |id| !id.match?(/\A[1-9]\d*\z/) } || TicketJourney::PerformanceSettings.development_activities.where(id: activity_ids).count != activity_ids.size)
        errors.add(:base, 'Development activity mapping must use existing activities named Development.')
      end
      %w[performance_periodic_dtc_target performance_periodic_priority_dtc_target performance_periodic_owner_share].each do |key|
        next if config[key].blank?
        unless TicketJourney::PerformanceSettings.periodic_target(config, key)
          errors.add(:base, "#{key.humanize} must be finite and nonnegative (owner share allows 0 through 100%).")
        end
      end
      %w[performance_estimate_allowance performance_sv_warning performance_live_owner_share].each do |key|
        if config.key?(key) && !TicketJourney::PerformanceSettings.parse_target(config[key])
          errors.add(:base, "#{key.humanize} must be a number between 0 and 100.")
        end
      end
      if config.key?('performance_hours_per_day')
        hours = TicketJourney::WorkingCalendar.positive_number(config['performance_hours_per_day'])
        errors.add(:base, 'Working hours per day must be greater than 0 and at most 24.') unless hours && hours <= 24
      end
      if config.key?('performance_working_weekdays')
        days = Array(config['performance_working_weekdays']).map(&:to_s).reject(&:blank?)
        unless days.any? && days.all? { |day| day.match?(/\A[0-6]\z/) }
          errors.add(:base, 'Select at least one valid working weekday.')
        end
      end
      if config.key?('performance_holidays')
        config['performance_holidays'].to_s.lines.each do |line|
          next if line.strip.empty?
          token = line.strip.split(/\s+/, 2).first
          begin
            raise Date::Error unless token.match?(/\A\d{4}-\d{2}-\d{2}\z/)
            Date.iso8601(token)
          rescue Date::Error
            errors.add(:base, 'Each holiday must start with a valid YYYY-MM-DD date, followed by an optional description.')
            break
          end
        end
      end
      id = config['performance_weekly_hours_field_id'].to_s
      if id.present? && (!id.match?(/\A[1-9]\d*\z/) || !UserCustomField.where(id: id, field_format: %w[int float]).exists?)
        errors.add(:base, 'Weekly hours must map to an existing numeric User custom field.')
      end
    end

    def validate_performance_delivery_target
      return unless name == 'plugin_redmine_ticket_journey'
      config = value
      return unless config.is_a?(Hash)
      raw = config['performance_delivery_target']
      # Existing installations without this key use the default; new submissions
      # must supply a finite numeric percentage, including valid zero and 100.
      return unless config.key?('performance_delivery_target')
      unless TicketJourney::PerformanceSettings.parse_target(raw)
        errors.add(:base, 'Delivery Target (%) must be a number between 0 and 100.')
      end
    end
  end
end
