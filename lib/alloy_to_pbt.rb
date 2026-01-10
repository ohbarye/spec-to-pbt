# frozen_string_literal: true

require_relative "alloy_to_pbt/version"
require_relative "alloy_to_pbt/parser"
require_relative "alloy_to_pbt/property_pattern"
require_relative "alloy_to_pbt/type_inferrer"
require_relative "alloy_to_pbt/pattern_code_generator"
require_relative "alloy_to_pbt/generator"

module AlloyToPbt
  class Error < StandardError; end
  class ParseError < Error; end
end
