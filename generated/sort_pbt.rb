# frozen_string_literal: true

# Auto-generated Property-Based Tests from Alloy Specification
# Module: sort

require "pbt"

# Implementation stub - replace with your actual implementation
def sort(array)
  array.sort
end

RSpec.describe "sort" do
  describe "Sort Properties" do
    it "satisfies all sort properties" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer)) do |input|
          output = sort(input)

          # Property: Sorted
          raise "Sorted failed" unless output.each_cons(2).all? { |a, b| a <= b }

          # Property: LengthPreserved
          raise "LengthPreserved failed" unless input.length == output.length

          # Property: SameElements
          raise "SameElements failed" unless input.sort == output.sort

          # Property: Idempotent
          raise "Idempotent failed" unless sort(output) == output

        end
      end
    end
  end
end
