require File.expand_path('../test_helper', __dir__)

class PerformanceDashboardHelperTest < ActiveSupport::TestCase
  include PerformanceDashboardHelper

  test 'owner colors are stable across tabs and independent of selection order' do
    assert_equal performance_owner_color(1393), performance_owner_color('1393')
    assert_not_equal performance_owner_color(1393), performance_owner_color(1394)
    assert_match(/\Ahsl\([\d.]+, 65%, 35%\)\z/, performance_owner_color(1393))
  end

  test 'monthly output geometry includes target on its numeric scale without percent units' do
    points = [{ monthly_count: 0.0 }, { monthly_count: 2.0 }]
    geometry = performance_return_trend_geometry(points, keys: [:monthly_count], scale_values: [30.0], minimum: 1.0)
    assert_operator geometry[:maximum], :>=, 30.0
    assert_equal 1, geometry[:series].size
    small = performance_return_trend_geometry(points, keys: [:monthly_count], minimum: 1.0)
    assert_operator small[:maximum], :<, geometry[:maximum]
  end

  test 'five month trend evenly spaces all points across the chart' do
    points = Array.new(5) { { ratio: 50.0, adjusted_ratio: nil } }
    geometry = performance_return_trend_geometry(points)
    assert_equal [90, 260, 430, 600, 770], geometry[:series].first.map { |point| point[:x] }
    assert_equal 5, geometry[:series].last.size
    assert geometry[:series].last.all? { |point| point[:y].nil? }
  end

  test 'delivery trend uses a fixed 0 to 100 percent axis' do
    points = [{ count_ratio: 0.0, weight_ratio: nil }, { count_ratio: 50.0, weight_ratio: 80.0 },
      { count_ratio: 100.0, weight_ratio: 100.0 }]
    geometry = performance_return_trend_geometry(points, keys: [:count_ratio, :weight_ratio], maximum: 100.0)
    assert_equal 25.0, geometry[:step]
    assert_equal [235.0, 135.0, 35.0], geometry[:series].first.map { |point| point[:y] }
    assert_nil geometry[:series].last.first[:y]
  end

  test 'return ratio colors share inclusive orange thresholds and neutral missing values' do
    assert_equal 'performance-return-positive', performance_return_ratio_class(0)
    assert_equal 'performance-return-positive', performance_return_ratio_class(9.6)
    assert_equal 'performance-return-warning', performance_return_ratio_class(10)
    assert_equal 'performance-return-warning', performance_return_ratio_class(50)
    assert_equal 'performance-return-negative', performance_return_ratio_class(50.01)
    assert_equal 'performance-return-negative', performance_return_ratio_class(200)
    assert_equal 'performance-return-unavailable', performance_return_ratio_class(nil)
  end

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
