# frozen_string_literal: true

# rbs_inline: enabled

require "erb"

module AlloyToPbt
  # Property data for template rendering
  # @rbs name: String
  # @rbs check_code: String?
  Property = Data.define(:name, :check_code)

  # Generates Ruby PBT code from Alloy specification using unified generator
  class Generator
    TEMPLATES_DIR = File.expand_path("templates", __dir__ || __FILE__) #: String

    # @rbs!
    #   type pattern_info = {
    #     predicate: Predicate,
    #     patterns: Array[Symbol]
    #   }
    #
    #   type property_data = {
    #     predicate: Predicate,
    #     generator_code: String,
    #     check_code: String?,
    #     unsupported_patterns: Array[Symbol]
    #   }

    attr_reader :spec #: Spec
    attr_reader :detected_patterns #: Hash[String, pattern_info]

    # @rbs spec: Spec
    # @rbs return: void
    def initialize(spec)
      @spec = spec
      @detected_patterns = {} #: Hash[String, pattern_info]
      @type_inferrer = nil #: TypeInferrer?
      @generated_properties = [] #: Array[property_data]
    end

    # Analyze predicates and detect patterns
    # @rbs return: Hash[String, pattern_info]
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
    # @rbs return: String
    def generate
      analyze

      @type_inferrer = TypeInferrer.new(@spec)
      @generated_properties = build_properties

      template_path = File.join(TEMPLATES_DIR, "unified.erb")
      template = ERB.new(File.read(template_path), trim_mode: "-")
      template.result(binding)
    end

    private

    # Build property data for template rendering
    # @rbs return: Array[property_data]
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

    # Infer Pbt generator code from predicate
    # Always generates array type since patterns (size, roundtrip, etc.) expect collections
    # @rbs predicate: Predicate
    # @rbs return: String
    def infer_generator(predicate)
      # Always use array for consistency with patterns
      # Patterns like size, roundtrip work on collections
      "Pbt.array(Pbt.integer)"
    end

    # Generate check code for supported patterns
    # @rbs patterns: Array[Symbol]
    # @rbs predicate: Predicate
    # @rbs return: String?
    def generate_check_code(patterns, predicate)
      return nil if patterns.empty?

      context = build_context(predicate)

      # Collect all non-nil code blocks
      codes = patterns.filter_map do |pattern|
        PatternCodeGenerator.generate(pattern, context)
      end

      return nil if codes.empty?

      # Deduplicate output/result definitions
      lines = [] #: Array[String]
      defined_vars = {} #: Hash[String, bool]

      codes.each do |code|
        code.lines.map(&:strip).each do |line|
          # Check for variable assignments like "output = " or "result = "
          if line.match?(/^(output|result|twice|restored) = /)
            var_name = line.split(" = ").first
            unless defined_vars[var_name]
              lines << line
              defined_vars[var_name] = true
            end
          else
            lines << line
          end
        end
      end

      lines.join("\n")
    end

    # Build context for pattern code generation (generic - uses module_name as operation)
    # @rbs predicate: Predicate
    # @rbs return: Hash[Symbol, untyped]
    def build_context(predicate)
      # Use module_name as the operation name (generic approach)
      operation = @spec.module_name || "operation"

      { operation: operation } #: Hash[Symbol, untyped]
    end
  end
end
