require 'date'
require 'set'

module TicketJourney
  # Current organization calendar. Date-only schedules use whole working days.
  class WorkingCalendar
    DEFAULT_WEEKDAYS = [1, 2, 3, 4, 5].freeze
    attr_reader :weekdays, :holidays, :hours_per_day

    def self.positive_number(value)
      number = Float(value.to_s, exception: false)
      number if number && number.finite? && number.positive?
    end

    def self.holiday_dates(value)
      value.to_s.lines.filter_map do |line|
        token = line.strip.split(/\s+/, 2).first
        Date.iso8601(token) if token && token.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      end
    end

    def initialize(settings)
      configured = Array(settings['performance_working_weekdays']).map(&:to_s)
      @weekdays = configured.grep(/\A[0-6]\z/).map(&:to_i).uniq
      @weekdays = DEFAULT_WEEKDAYS if @weekdays.empty?
      @holidays = self.class.holiday_dates(settings['performance_holidays']).to_set
      hours = self.class.positive_number(settings['performance_hours_per_day'])
      @hours_per_day = hours && hours <= 24 ? hours : 8.0
    rescue Date::Error
      # Invalid legacy settings must not break reports. Saving rejects them.
      @holidays = Set.new
      hours = self.class.positive_number(settings['performance_hours_per_day'])
      @hours_per_day = hours && hours <= 24 ? hours : 8.0
    end

    def working_day?(date)
      weekdays.include?(date.wday) && !holidays.include?(date)
    end

    # Inclusive count, computed by weeks plus a maximum six-day remainder.
    def days(first, last)
      return 0 unless first && last && last >= first
      weeks, remainder = ((last - first).to_i + 1).divmod(7)
      count = weeks * weekdays.size
      remainder.times { |offset| count += 1 if weekdays.include?((first + offset).wday) }
      count - holidays.count { |day| day.between?(first, last) && weekdays.include?(day.wday) }
    end

    def age(start, date)
      return unless start && start <= date
      days(start + 1, date)
    end

    def elapsed_fraction(start, due, date, daily_hours: hours_per_day)
      return unless start && due && due > start
      window = days(start, due) * daily_hours
      return unless window.positive?
      [[days(start, [date, due].min) * daily_hours / window, 0.0].max, 1.0].min
    end
  end
end
