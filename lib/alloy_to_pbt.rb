# frozen_string_literal: true

# rbs_inline: enabled

require_relative "alloy_to_pbt/version"
require_relative "alloy_to_pbt/parser"
require_relative "alloy_to_pbt/property_pattern"
require_relative "alloy_to_pbt/type_inferrer"
require_relative "alloy_to_pbt/pattern_code_generator"
require_relative "alloy_to_pbt/generator"
require_relative "alloy_to_pbt/stateful_generator"

module AlloyToPbt
  # Base error class for AlloyToPbt
  class Error < StandardError; end

  # Raised when parsing Alloy specification fails
  class ParseError < Error; end
end
