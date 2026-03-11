# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  GuardAnalysis = Data.define(
    :kind,
    :field,
    :constant,
    :comparator,
    :argument_name,
    :support_level
  ) do
    # @rbs kind: Symbol
    # @rbs field: String?
    # @rbs constant: String?
    # @rbs comparator: Symbol?
    # @rbs argument_name: String?
    # @rbs support_level: Symbol
    # @rbs return: void
    def initialize(kind: :none, field: nil, constant: nil, comparator: nil, argument_name: nil, support_level: :none) = super
  end
end
