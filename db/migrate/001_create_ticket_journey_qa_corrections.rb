class CreateTicketJourneyQaCorrections < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_journey_qa_corrections do |table|
      table.bigint :issue_id, null: false
      table.bigint :journal_detail_id, null: false
      table.bigint :user_id, null: false
      table.boolean :excluded, null: false
      table.text :reason, null: false
      table.datetime :created_at, null: false
      table.index [:issue_id, :journal_detail_id, :id], name: 'idx_tj_qa_corrections_issue_event'
    end
  end
end
