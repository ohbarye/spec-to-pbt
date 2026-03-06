# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecToPbt::StatefulConfigName do
  describe ".for" do
    it "derives a constant name and config basename from the spec name" do
      result = described_class.for("stack")

      expect(result[:constant_name]).to eq("StackPbtConfig")
      expect(result[:file_basename]).to eq("stack_pbt_config")
    end
  end
end
