module StreamEvents
  class ClassificationEvent
    def initialize(hash)
      @data = hash.fetch("data")
      @linked = StreamEvents.linked_to_hash(hash.fetch("linked"))
    end

    def enabled?
      true
    end

    def process
      cache_linked_models!

      workflow = Workflow.find(classification.workflow_id)
      workflow.classification_pipeline.process(classification)
    end

    def cache_linked_models!
      Workflow.update_cache(linked_workflow)

      linked_subjects.each do |linked_subject|
        Subject.update_cache(linked_subject)
      end
    end

    private

    def classification
      @classification ||= Classification.new(@data)
    end

    def linked_workflow
      id = @data.fetch("links").fetch("workflow")
      @linked.fetch("workflows").fetch(id)
    end

    def linked_subjects
      @linked.fetch("subjects").values
    end
  end
end
