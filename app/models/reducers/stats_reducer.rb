module Reducers
  class StatsReducer < Reducer
    attr_reader :sub_ranges

    def reduction_data_for(extractions)
      ReductionResults.build do |results|
        extractions.each do |extraction|
          extraction.data.each do |key, value|
            case value
            when TrueClass, FalseClass
              results.increment(key, value ? 1 : 0)
            else
              results.increment(key, value)
            end
          end
        end
      end
    end
  end
end