# frozen_string_literal: true

module AlloyToPbt
  # Generates Ruby check code from detected property patterns
  class PatternCodeGenerator
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
    }.freeze

    SUPPORTED_PATTERNS = PATTERN_HANDLERS.keys.freeze

    # Check if a pattern is supported
    # @param pattern [Symbol] the pattern name
    # @return [Boolean]
    def self.supported?(pattern)
      SUPPORTED_PATTERNS.include?(pattern)
    end

    # Generate check code for a pattern
    # @param pattern [Symbol] the pattern name
    # @param context [Hash] context for code generation
    # @return [String, nil] generated code or nil if unsupported
    def self.generate(pattern, context = {})
      handler = PATTERN_HANDLERS[pattern]
      return nil unless handler

      handler.call(context)
    end
  end
end
