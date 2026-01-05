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
  end
end
