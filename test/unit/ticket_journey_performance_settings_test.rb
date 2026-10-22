require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceSettingsTest < ActiveSupport::TestCase
  test 'time settings reject impossible calendars thresholds and field mappings' do
    setting = Setting.find_by(name: 'plugin_redmine_ticket_journey') || Setting.new(name: 'plugin_redmine_ticket_journey')
    invalid = [
      { 'performance_working_weekdays' => [''] }, { 'performance_working_weekdays' => ['7'] },
      { 'performance_holidays' => '2026-02-30 Invalid' }, { 'performance_holidays' => 'October 2' },
      { 'performance_hours_per_day' => '0' }, { 'performance_hours_per_day' => '25' },
      { 'performance_sv_warning' => '-1' }, { 'performance_estimate_allowance' => 'Infinity' },
      { 'performance_weekly_hours_field_id' => '999999999' }
    ]
    invalid.each do |config|
      setting.value = config
      assert_not setting.valid?, "Expected rejection for #{config.inspect}"
    end
    setting.value = { 'performance_working_weekdays' => ['', '1', '2'], 'performance_hours_per_day' => '7.5',
      'performance_holidays' => "2026-12-25 Holiday\n2027-01-01\n", 'performance_sv_warning' => '10',
      'performance_estimate_allowance' => '0', 'performance_weekly_hours_field_id' => '' }
    assert setting.valid?, setting.errors.full_messages.join(', ')
  end

  test 'legacy settings use 90 and valid boundary and decimal values are preserved' do
    assert_equal 90, TicketJourney::PerformanceSettings.delivery_target({})
    %w[0 90 92.5 100].each do |value|
      assert_equal value.to_f, TicketJourney::PerformanceSettings.delivery_target('performance_delivery_target' => value)
    end
  end

  test 'invalid target values are rejected when saving plugin settings' do
    setting = Setting.find_by(name: 'plugin_redmine_ticket_journey') || Setting.new(name: 'plugin_redmine_ticket_journey')
    ['', '-1', '101', 'NaN', 'Infinity', 'abc'].each do |value|
      setting.value = { 'performance_delivery_target' => value }
      assert_not setting.valid?, "Expected rejection for #{value.inspect}"
      assert_includes setting.errors.full_messages.join(' '), 'Delivery Target (%)'
    end
    setting.value = { 'performance_delivery_target' => '92.5' }
    assert setting.valid?, setting.errors.full_messages.join(', ')
    setting.value = { 'performance_start_date' => '' }
    assert setting.valid?, 'Existing settings without the new key must remain valid'
  end
end
