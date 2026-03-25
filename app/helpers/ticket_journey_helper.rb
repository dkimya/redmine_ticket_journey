module TicketJourneyHelper
  def d_fields
    [
    { key: :D1,    label: 'D1',     aug: false, desc: 'Planning (New → To-Do)' },
    { key: :D2,    label: 'D2',     aug: false, desc: 'Wait for Dev (1st)' },
    { key: :D2aug, label: 'D2-aug', aug: true,  desc: 'Wait for Dev (returns)' },
    { key: :D3,    label: 'D3',     aug: false, desc: 'Under Development (1st)' },
    { key: :D3aug, label: 'D3-aug', aug: true,  desc: 'Under Dev (subsequent)' },
    { key: :D4,    label: 'D4',     aug: false, desc: 'QA Time (1st)' },
    { key: :D4aug, label: 'D4-aug', aug: true,  desc: 'QA Time (returns)' },
    { key: :D5,    label: 'D5',     aug: false, desc: 'Review → Ready to Merge' },
    { key: :D5aug, label: 'D5-aug', aug: true,  desc: 'Review → Returned' },
    { key: :D6,    label: 'D6',     aug: false, desc: 'Ready to Merge → Final Check' },
    { key: :D6aug, label: 'D6-aug', aug: true,  desc: 'Ready to Merge → Returned' },
    { key: :D7aug, label: 'D7-aug', aug: true,  desc: 'Post-Integration QA' },
    { key: :D7,    label: 'D7',     aug: false, desc: 'Final pass → Done gap' },
  ]
  end

  def format_hours(h)
    return '—' if h.nil? || h == 0
    h = h.to_f
    total_minutes = (h * 60).round
    days    = total_minutes / (60 * 24)
    hours   = (total_minutes % (60 * 24)) / 60
    minutes = total_minutes % 60
    parts = []
    parts << "#{days}d"    if days > 0
    parts << "#{hours}h"   if hours > 0
    parts << "#{minutes}m" if minutes > 0 && days == 0
    parts.empty? ? '0m' : parts.join(' ')
  end

  def duration_css_class(h, aug: false)
    return 'tj-dur-zero' if h.nil? || h == 0
    base = aug ? 'tj-dur-aug' : 'tj-dur'
    base += ' tj-dur-high' if h.to_f > 48
    base
  end

  def counter_css_class(count)
    count.to_i > 0 ? 'tj-counter-active' : 'tj-counter-zero'
  end
end
