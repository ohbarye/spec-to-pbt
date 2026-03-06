# frozen_string_literal: true

# rbs_inline: enabled

require_relative "spec_to_pbt/version"
require_relative "spec_to_pbt/core"
require_relative "spec_to_pbt/parser"
require_relative "spec_to_pbt/frontends/alloy/parser"
require_relative "spec_to_pbt/frontends/alloy/adapter"
require_relative "spec_to_pbt/property_pattern"
require_relative "spec_to_pbt/type_inferrer"
require_relative "spec_to_pbt/pattern_code_generator"
require_relative "spec_to_pbt/generator"
require_relative "spec_to_pbt/stateful_predicate_analyzer"
require_relative "spec_to_pbt/stateful_generator"

module SpecToPbt
  # Base error class for SpecToPbt
  class Error < StandardError; end

  # Raised when parsing Alloy specification fails
  class ParseError < Error; end
end
