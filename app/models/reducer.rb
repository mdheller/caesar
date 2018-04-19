class Reducer < ApplicationRecord
  include Configurable

  enum topic: {
    reduce_by_subject: 0,
    reduce_by_user: 1
  }

  enum reduction_mode: {
    default_reduction: 0,
    running_reduction: 1
  }

  def self.of_type(type)
    case type.to_s
    when "consensus"
      Reducers::ConsensusReducer
    when "count"
      Reducers::CountReducer
    when 'placeholder'
      Reducers::PlaceholderReducer
    when "external"
      Reducers::ExternalReducer
    when "first_extract"
      Reducers::FirstExtractReducer
    when "stats"
      Reducers::StatsReducer
    when "summary_stats"
      Reducers::SummaryStatisticsReducer
    when "unique_count"
      Reducers::UniqueCountReducer
    else
      raise "Unknown type #{type}"
    end
  end

  belongs_to :workflow

  validates :workflow, presence: true
  validates :key, presence: true, uniqueness: {scope: [:workflow_id]}
  validates :topic, presence: true
  validates_associated :extract_filter

  before_validation :nilify_empty_fields

  NoData = Class.new

  def process(extract_fetcher, reduction_fetcher)
    light = Stoplight("reducer-#{id}") do
      # if any of the reductions that this reducer cares about have expired, we're
      # going to need to fetch all of the relevant extracts in order to rebuild them
      if reduction_fetcher.has_expired?
        extract_fetcher.strategy! :fetch_all
      end

      grouped_extracts = ExtractGrouping.new(extract_fetcher.extracts, grouping).to_h

      grouped_extracts.map do |group_key, grouped|
        reduction = get_reduction(reduction_fetcher, group_key)
        extracts = filter_extracts(grouped, reduction)

        reduce_into(extracts, reduction).tap do |r|
          r.expired = false

          # note that because we use deferred associations, this won't actually hit the database
          # until the reduction is saved, meaning it happens inside the transaction
          associate_extracts(r, extracts) if running_reduction?
        end
      end.reject{ |reduction| reduction.data.blank? }
    end

    light.run
  end

  def get_reduction(reduction_fetcher, group_key)
    reduction_fetcher.retrieve(key, group_key).first_or_initialize.tap do |r|
      r.data = if running_reduction? then (r.data || {}) else {} end
      r.store = if running_reduction? then (r.store || {}) else {} end
    end
  end

  def filter_extracts(extracts, reduction)
    extracts = extracts.reject{ |extract| reduction.extract_ids.include? extract.id }
    extract_filter.filter(extracts)
  end

  def associate_extracts(reduction, extracts)
    reduction.extract.delete_all
    reduction.extract << extracts
  end

  def reduce_into(extracts, reduction)
    raise NotImplementedError
  end

  def extract_filter
    ExtractFilter.new(filters)
  end

  def config
    super || {}
  end

  def filters
    super || {}
  end

  def nilify_empty_fields
    self.grouping = nil if grouping.blank?
  end
end
