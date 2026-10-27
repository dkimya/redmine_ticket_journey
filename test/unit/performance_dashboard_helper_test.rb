require File.expand_path('../test_helper', __dir__)

class PerformanceDashboardHelperTest < ActiveSupport::TestCase
  include PerformanceDashboardHelper

  test 'Periodic owner links replace team selection and retain range and detail context' do
    @selected_owner_ids = %w[1 2]
    @period_start, @period_end, @date = Date.new(2026, 3, 1), Date.new(2026, 3, 31), Date.new(2026, 10, 1)
    individual = periodic_ticket_params({ metric: 'completed' }, ids: ['2'])
    assert_equal '2', individual[:owner_id]
    assert_nil individual[:owner_ids]
    assert_equal 'periodic', individual[:dashboard_type]
    assert_equal '2026-03-01', individual[:rsd]
    assert_equal '2026-03-31', individual[:red]
    assert_equal '2026-10-01', individual[:as_of]
    @periodic_tickets, @metric, @trend_date = true, 'trend_completed', @period_end
    @sort, @direction, @group_by = 'weight', 'desc', 'owner'
    context = performance_detail_params(page: 2)
    assert_equal %w[1 2], context[:owner_ids]
    assert_equal '2026-03-31', context[:trend_date]
    assert_equal 'owner', context[:group_by]
    assert_equal 2, context[:page]
  end

  test 'Time signs zero and threshold boundaries distinguish SV from estimate allowance' do
    assert_equal 'performance-return-unavailable', performance_time_state(nil, 10)
    assert_equal 'performance-return-unavailable', performance_time_state(0, 10)
    assert_equal 'performance-return-positive', performance_time_state(1, 10)
    assert_equal 'performance-return-warning', performance_time_state(-9.99, 10)
    assert_equal 'performance-return-negative', performance_time_state(-10, 10)
    assert_equal 'performance-return-warning', performance_time_state(-10, 10, inclusive: false)
    assert_equal 'performance-return-negative', performance_time_state(-10.01, 10, inclusive: false)
  end

  test 'leaderboard axes reduce whitespace and include data and targets without capping future values' do
    points = performance_leaderboard_geometry([{ '1' => 211.0 }], keys: ['1'], scale_values: [160], percent: false)
    assert_equal 300.0, points[:maximum]
    assert_equal [0, 100, 200, 300], points[:ticks]
    returns = performance_leaderboard_geometry([{ '1' => 112.5 }], keys: ['1'], scale_values: [10, 50], percent: true)
    assert_equal 125.0, returns[:maximum]
    assert_equal [0, 25, 50, 75, 100, 125], returns[:ticks]
    target = performance_leaderboard_geometry([{ '1' => 211.0 }], keys: ['1'], scale_values: [420], percent: false)
    assert_operator target[:maximum], :>=, 420
    future = performance_leaderboard_geometry([{ '1' => 1350.0 }], keys: ['1'], scale_values: [160], percent: false)
    assert_operator future[:maximum], :>=, 1350
    assert future[:series].flatten.all? { |point| (35..235).cover?(point[:y]) }
    empty = performance_leaderboard_geometry([{ '1' => nil }], keys: ['1'], scale_values: [10, 50], percent: true)
    assert_equal 50.0, empty[:maximum]
    assert_nil empty[:series].first.first[:y]
  end

  test 'owner colors are stable across tabs and independent of selection order' do
    assert_equal performance_owner_color(1393), performance_owner_color('1393')
    assert_not_equal performance_owner_color(1393), performance_owner_color(1394)
    assert_match(/\A#[0-9A-F]{6}\z/, performance_owner_color(1393))
  end

  test 'selected owners get distinct palette colors even when old ID hashes were similar' do
    @selected_owner_ids = %w[1393 70 1414 1373 1500]
    colors = @selected_owner_ids.to_h { |id| [id, performance_owner_color(id)] }
    assert_equal 5, colors.values.uniq.size
    assert_equal %w[#0072B2 #D55E00 #009E73 #7B2CBF #C62828].sort, colors.values.sort
    @selected_owner_ids = @selected_owner_ids.reverse
    assert_equal colors, @selected_owner_ids.to_h { |id| [id, performance_owner_color(id)] }
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
