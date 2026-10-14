require File.expand_path('../test_helper', __dir__)

class TicketJourneyPerformanceSettingsTest < ActiveSupport::TestCase
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
