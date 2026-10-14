module PerformanceDashboardHelper
  def performance_number(value)
    value.nil? ? 'N/A' : number_with_precision(value, precision: 1, strip_insignificant_zeros: true)
  end

  def performance_percent(numerator, denominator)
    denominator.positive? ? numerator.to_f * 100 / denominator : nil
  end

  def performance_tip(text)
    content_tag(:span, 'ⓘ', title: text, tabindex: 0, class: 'performance-tip', 'aria-label': text)
  end
end
