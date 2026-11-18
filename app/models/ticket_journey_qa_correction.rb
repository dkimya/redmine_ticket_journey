class TicketJourneyQaCorrection < ActiveRecord::Base
  validates :issue_id, :journal_detail_id, :user_id, presence: true
  validates :reason, presence: true, length: { maximum: 1000 }
  validates :excluded, inclusion: { in: [true, false] }
end
