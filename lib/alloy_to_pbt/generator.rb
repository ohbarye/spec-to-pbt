# frozen_string_literal: true

require "erb"

module AlloyToPbt
  # Property data for template rendering
  Property = Data.define(:name, :check_code)

  # Generates Ruby PBT code from Alloy specification
  class Generator
    TEMPLATES_DIR = File.expand_path("templates", __dir__)

    attr_reader :spec, :detected_patterns

    def initialize(spec)
      @spec = spec
      @detected_patterns = {}
    end

    # Analyze predicates and detect patterns
    def analyze
      @spec.predicates.each do |pred|
        patterns = PropertyPattern.detect(pred.name, pred.body)
        @detected_patterns[pred.name] = {
          predicate: pred,
          patterns: patterns
        }
      end
      @detected_patterns
    end

    # Generate Ruby PBT code
    def generate
      analyze

      template_name = detect_template_type
      template_path = File.join(TEMPLATES_DIR, "#{template_name}.erb")

      unless File.exist?(template_path)
        raise Error, "Template not found: #{template_path}"
      end

      template = ERB.new(File.read(template_path), trim_mode: "-")
      template.result(binding)
    end

    private

    def detect_template_type
      module_name = @spec.module_name&.downcase || ""

      if module_name.include?("sort")
        "sort"
      elsif module_name.include?("stack")
        "stack"
      elsif module_name.include?("queue")
        "queue"
      elsif module_name.include?("set")
        "set"
      else
        "generic"
      end
    end

    # Helper methods for templates
    def properties_for_sort
      [
        Property.new(
          name: "Sorted",
          check_code: 'raise "Sorted failed" unless output.each_cons(2).all? { |a, b| a <= b }'
        ),
        Property.new(
          name: "LengthPreserved",
          check_code: 'raise "LengthPreserved failed" unless input.length == output.length'
        ),
        Property.new(
          name: "SameElements",
          check_code: 'raise "SameElements failed" unless input.sort == output.sort'
        ),
        Property.new(
          name: "Idempotent",
          check_code: 'raise "Idempotent failed" unless sort(output) == output'
        )
      ]
    end

    def properties_for_stack
      {
        push_adds: Property.new(
          name: "PushAddsElement",
          check_code: 'raise "PushAddsElement failed" unless stack.length == original_length + 1'
        ),
        pop_removes: Property.new(
          name: "PopRemovesElement",
          check_code: 'raise "PopRemovesElement failed" unless stack.length == original_length - 1'
        ),
        lifo: Property.new(
          name: "LIFO",
          check_code: 'raise "LIFO failed" unless popped == element'
        ),
        push_pop_identity: Property.new(
          name: "PushPopIdentity",
          check_code: 'raise "PushPopIdentity failed" unless stack.length == original_length'
        )
      }
    end

    def properties_for_queue
      {
        enqueue_adds: Property.new(
          name: "EnqueueAddsElement",
          check_code: 'raise "EnqueueAddsElement failed" unless queue.length == original_length + 1'
        ),
        dequeue_removes: Property.new(
          name: "DequeueRemovesElement",
          check_code: 'raise "DequeueRemovesElement failed" unless queue.length == original_length - 1'
        ),
        fifo: Property.new(
          name: "FIFO",
          check_code: 'raise "FIFO failed" unless dequeued == element'
        ),
        enqueue_dequeue_identity: Property.new(
          name: "EnqueueDequeueIdentity",
          check_code: 'raise "EnqueueDequeueIdentity failed" unless queue.length == original_length'
        )
      }
    end

    def properties_for_set
      {
        add_contains: Property.new(
          name: "AddContains",
          check_code: 'raise "AddContains failed" unless set.contains?(element)'
        ),
        remove_not_contains: Property.new(
          name: "RemoveNotContains",
          check_code: 'raise "RemoveNotContains failed" if set.contains?(element)'
        ),
        union_commutative: Property.new(
          name: "UnionCommutative",
          check_code: 'raise "UnionCommutative failed" unless set_a.union(set_b) == set_b.union(set_a)'
        ),
        union_associative: Property.new(
          name: "UnionAssociative",
          check_code: 'raise "UnionAssociative failed" unless set_a.union(set_b).union(set_c) == set_a.union(set_b.union(set_c))'
        ),
        intersection_commutative: Property.new(
          name: "IntersectionCommutative",
          check_code: 'raise "IntersectionCommutative failed" unless set_a.intersection(set_b) == set_b.intersection(set_a)'
        )
      }
    end
  end
end
