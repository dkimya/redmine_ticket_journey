require File.expand_path('../test_helper', __dir__)

class PerformanceDashboardHelperTest < ActiveSupport::TestCase
  include PerformanceDashboardHelper

  test 'return trend scale has a zero baseline and accommodates ratios above 100 percent' do
    points = [{ ratio: 0.0, adjusted_ratio: 0.0 }, { ratio: 125.0, adjusted_ratio: 100.0 },
              { ratio: 350.0, adjusted_ratio: nil }]
    geometry = performance_return_trend_geometry(points)
    assert_operator geometry[:maximum], :>=, 350
    assert_equal 235, geometry[:series].first.first[:y]
    assert_nil geometry[:series].last.last[:y]
    assert_equal [90, 430, 770], geometry[:series].first.map { |point| point[:x] }
    assert geometry[:series].flatten.all? { |point| point[:y].nil? || (35..235).cover?(point[:y]) }
  end

  test 'empty return trend has a usable axis and leaves missing points as gaps' do
    geometry = performance_return_trend_geometry(Array.new(3) { { ratio: nil, adjusted_ratio: nil } })
    assert_operator geometry[:maximum], :>, 0
    assert geometry[:series].flatten.all? { |point| point[:y].nil? }
  end
end
