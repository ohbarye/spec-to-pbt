# frozen_string_literal: true

require "erb"

module AlloyToPbt
  # Property data for template rendering
  Property = Data.define(:name, :check_code)

  # Generates Ruby PBT code from Alloy specification using unified generator
  class Generator
    TEMPLATES_DIR = File.expand_path("templates", __dir__)

    attr_reader :spec, :detected_patterns

    def initialize(spec)
      @spec = spec
      @detected_patterns = {}
      @type_inferrer = nil
      @generated_properties = []
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

    # Generate Ruby PBT code using unified template
    def generate
      analyze

      @type_inferrer = TypeInferrer.new(@spec)
      @generated_properties = build_properties

      template_path = File.join(TEMPLATES_DIR, "unified.erb")
      template = ERB.new(File.read(template_path), trim_mode: "-")
      template.result(binding)
    end

    private

    def build_properties
      @detected_patterns.map do |pred_name, info|
        patterns = info[:patterns]
        predicate = info[:predicate]

        supported = patterns.select { |p| PatternCodeGenerator.supported?(p) }
        unsupported = patterns - supported

        {
          predicate: predicate,
          generator_code: infer_generator(predicate),
          check_code: generate_check_code(supported, predicate),
          unsupported_patterns: unsupported
        }
      end
    end

    def infer_generator(predicate)
      # Find the main type from predicate parameters or use default
      if predicate.params.any?
        param = predicate.params.first
        @type_inferrer.generator_for(param[:type])
      else
        "Pbt.array(Pbt.integer)"
      end
    end

    def generate_check_code(patterns, predicate)
      return nil if patterns.empty?

      context = build_context(predicate)

      # Collect all non-nil code blocks
      codes = patterns.filter_map do |pattern|
        PatternCodeGenerator.generate(pattern, context)
      end

      return nil if codes.empty?

      # For data structures like stack/queue, each pattern generates complete code
      # Just join them without output deduplication
      if context[:data_structure]
        codes.join("\n")
      else
        # For sort-like operations, deduplicate output definitions
        lines = []
        output_defined = false

        codes.each do |code|
          code.lines.map(&:strip).each do |line|
            if line.start_with?("output = ")
              unless output_defined
                lines << line
                output_defined = true
              end
            else
              lines << line
            end
          end
        end

        lines.join("\n")
      end
    end

    def build_context(predicate)
      name = predicate.name.downcase
      module_name = @spec.module_name&.downcase || ""
      context = {}

      # Infer operation name from module name first, then predicate name
      if module_name.include?("sort") || name.include?("sort")
        context[:operation] = "sort"
        context[:invariant_check] = "each_cons(2).all? { |a, b| a <= b }"
      elsif module_name.include?("stack")
        context[:operation] = "process_stack"
        context[:operations] = %w[push pop]
        context[:data_structure] = :stack
      elsif module_name.include?("queue")
        context[:operation] = "process_queue"
        context[:operations] = %w[enqueue dequeue]
        context[:data_structure] = :queue
      elsif name.include?("push") && name.include?("pop")
        context[:operations] = %w[push pop]
      elsif name.include?("enqueue") && name.include?("dequeue")
        context[:operations] = %w[enqueue dequeue]
      elsif name.include?("add") && name.include?("remove")
        context[:operations] = %w[add remove]
      end

      context
    end
  end
end
