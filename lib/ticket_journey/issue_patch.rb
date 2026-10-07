module TicketJourney
  module IssuePatch
    def tj_return_count
      return @tj_return_count if instance_variable_defined?(:@tj_return_count)
      return 0 unless persisted?

      self.class.where(id: id).pick(Arel.sql(ReturnCount.sql)).to_i
    end

    def reload(*args, **options)
      remove_instance_variable(:@tj_return_count) if instance_variable_defined?(:@tj_return_count)
      super
    end
  end
end
