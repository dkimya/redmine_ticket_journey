module TicketJourney
  module PerformanceSettings
    DEFAULT_DELIVERY_TARGET = 90.0

    def self.parse_target(value)
      number = Float(value.to_s, exception: false)
      number if number && number.finite? && number.between?(0, 100)
    end

    def self.delivery_target(settings)
      parse_target(settings['performance_delivery_target']) || DEFAULT_DELIVERY_TARGET
    end

    def self.included(base)
      base.validate :validate_performance_delivery_target
    end

    private

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
