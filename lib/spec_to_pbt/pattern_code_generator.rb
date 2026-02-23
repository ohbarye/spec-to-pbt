# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  # Generates Ruby check code from detected property patterns
  # Generic implementation - no special cases for specific data structures
  class PatternCodeGenerator
    # Pattern → check code generation logic (generic templates)
    PATTERN_HANDLERS = {
      idempotent: ->(ctx) {
        op = ctx[:operation]
        <<~RUBY.strip
          result = #{op}(input)
          twice = #{op}(result)
          raise "Idempotent failed" unless result == twice
        RUBY
      },

      size: ->(ctx) {
        op = ctx[:operation]
        <<~RUBY.strip
          output = #{op}(input)
          raise "Size failed" unless input.length == output.length
        RUBY
      },

      roundtrip: ->(ctx) {
        op = ctx[:operation]
        <<~RUBY.strip
          result = #{op}(input)
          restored = #{op}(result)
          raise "Roundtrip failed" unless restored == input
        RUBY
      },

      invariant: ->(ctx) {
        op = ctx[:operation]
        <<~RUBY.strip
          output = #{op}(input)
          raise "Invariant failed" unless invariant?(output)
        RUBY
      }
    }.freeze #: Hash[Symbol, ^(Hash[Symbol, untyped]) -> String?]

    SUPPORTED_PATTERNS = PATTERN_HANDLERS.keys.freeze #: Array[Symbol]

    # Check if a pattern is supported
    # @rbs pattern: Symbol
    # @rbs return: bool
    def self.supported?(pattern)
      SUPPORTED_PATTERNS.include?(pattern)
    end

    # Generate check code for a pattern
    # @rbs pattern: Symbol
    # @rbs context: Hash[Symbol, untyped]
    # @rbs return: String?
    def self.generate(pattern, context = {})
      handler = PATTERN_HANDLERS[pattern]
      return nil unless handler

      handler.call(context)
    end
  end
end
