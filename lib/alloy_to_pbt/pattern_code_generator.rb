# frozen_string_literal: true

# rbs_inline: enabled

module AlloyToPbt
  # Generates Ruby check code from detected property patterns
  class PatternCodeGenerator
    # Pattern handler context type
    # @rbs!
    #   type context = {
    #     operation: String?,
    #     operations: Array[String]?,
    #     data_structure: Symbol?,
    #     invariant_check: String?
    #   }

    # Pattern → check code generation logic
    PATTERN_HANDLERS = {
      idempotent: ->(ctx) {
        op = ctx[:operation] || "sort"
        <<~RUBY.strip
          output = #{op}(input)
          twice = #{op}(output)
          raise "Idempotent failed" unless output == twice
        RUBY
      },

      size: ->(ctx) {
        if ctx[:data_structure] == :stack
          <<~RUBY.strip
            stack = Stack.new
            original_length = stack.length
            stack.push(input)
            raise "Size failed" unless stack.length == original_length + 1
          RUBY
        elsif ctx[:data_structure] == :queue
          <<~RUBY.strip
            queue = Queue.new
            original_length = queue.length
            queue.enqueue(input)
            raise "Size failed" unless queue.length == original_length + 1
          RUBY
        else
          op = ctx[:operation] || "sort"
          <<~RUBY.strip
            output = #{op}(input)
            raise "Size failed" unless input.length == output.length
          RUBY
        end
      },

      roundtrip: ->(ctx) {
        ops = ctx[:operations] || %w[push pop]
        if ctx[:data_structure] == :stack
          <<~RUBY.strip
            stack = Stack.new
            stack.push(input)
            popped = stack.pop
            raise "Roundtrip failed" unless popped == input
          RUBY
        elsif ctx[:data_structure] == :queue
          <<~RUBY.strip
            queue = Queue.new
            queue.enqueue(input)
            dequeued = queue.dequeue
            raise "Roundtrip failed" unless dequeued == input
          RUBY
        else
          <<~RUBY.strip
            original = input.dup
            #{ops[0]}(input, value)
            #{ops[1]}(input)
            raise "Roundtrip failed" unless input == original
          RUBY
        end
      },

      invariant: ->(ctx) {
        # invariant is typically not applicable to stack/queue in the same way
        # For stack/queue, we skip generating invariant code
        if ctx[:data_structure] == :stack || ctx[:data_structure] == :queue
          nil
        else
          op = ctx[:operation] || "sort"
          check = ctx[:invariant_check] || "each_cons(2).all? { |a, b| a <= b }"
          <<~RUBY.strip
            output = #{op}(input)
            raise "Invariant failed" unless output.#{check}
          RUBY
        end
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
