require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceSettingsTest < ActiveSupport::TestCase
  test 'development activities map existing records and allow an explicit empty selection' do
    activity = TimeEntryActivity.find_by(name: 'Development') || TimeEntryActivity.create!(name: 'Development')
    setting = Setting.find_by(name: 'plugin_redmine_ticket_journey') || Setting.new(name: 'plugin_redmine_ticket_journey')
    setting.value = { 'performance_periodic_development_activity_ids' => ['', activity.id.to_s] }
    assert setting.valid?, setting.errors.full_messages.join(', ')
    setting.value = { 'performance_periodic_development_activity_ids' => [''] }
    assert setting.valid?
    [['invalid'], ['999999999'], ['0']].each do |ids|
      setting.value = { 'performance_periodic_development_activity_ids' => ids }
      assert_not setting.valid?
    end
    qa = TimeEntryActivity.create!(name: 'Periodic Test QA')
    setting.value = { 'performance_periodic_development_activity_ids' => [qa.id.to_s] }
    assert_not setting.valid?
  end
  test 'Periodic Time targets use confirmed defaults preserve overrides and reject invalid inputs' do
    setting = Setting.find_by(name: 'plugin_redmine_ticket_journey') || Setting.new(name: 'plugin_redmine_ticket_journey')
    %w[performance_periodic_dtc_target performance_periodic_priority_dtc_target].each do |key|
      ['', nil].each { |value| assert_equal TicketJourney::PerformanceSettings::PERIODIC_DEFAULTS[key], TicketJourney::PerformanceSettings.periodic_target({ key => value }, key) }
      %w[-1 NaN Infinity invalid].each do |value|
        setting.value = { key => value }
        assert_not setting.valid?, "Expected invalid #{key}=#{value}"
      end
      setting.value = { key => '' }
      assert setting.valid?
      setting.value = { key => '7.5' }
      assert setting.valid?
      setting.value = { key => '0' }
      assert setting.valid?
    end
    %w[0 90 100].each do |value|
      setting.value = { 'performance_periodic_owner_share' => value }
      assert setting.valid?
      assert_equal value.to_f, TicketJourney::PerformanceSettings.periodic_target(setting.value, 'performance_periodic_owner_share')
    end
    %w[-1 101 NaN Infinity].each do |value|
      setting.value = { 'performance_periodic_owner_share' => value }
      assert_not setting.valid?
    end
    assert_equal 90.0, TicketJourney::PerformanceSettings.periodic_target({}, 'performance_periodic_owner_share')
    assert_equal 7.0, TicketJourney::PerformanceSettings.periodic_target({}, 'performance_periodic_dtc_target')
    assert_equal 3.0, TicketJourney::PerformanceSettings.periodic_target({}, 'performance_periodic_priority_dtc_target')
  end

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
