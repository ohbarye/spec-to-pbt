# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecToPbt::Frontends::Alloy::Adapter do
  describe "#adapt" do
    let(:parser) { SpecToPbt::Frontends::Alloy::Parser.new }

    it "maps Alloy parser output into a frontend-neutral core document" do
      source = File.read(File.expand_path("../../../fixtures/alloy/stack.als", __dir__))
      raw_spec = parser.parse(source)
      document = described_class.new.adapt(raw_spec)

      expect(document).to be_a(SpecToPbt::Core::SpecDocument)
      expect(document.name).to eq("stack")
      expect(document.source_format).to eq(:alloy)
      expect(document.types.map(&:name)).to contain_exactly("Element", "Stack")
      expect(document.properties.map(&:name)).to include("PushAddsElement", "PopRemovesElement", "PushPopIdentity")

      stack_type = document.types.find { |entity| entity.name == "Stack" }
      expect(stack_type.kind).to eq(:type)
      expect(stack_type.metadata[:category]).to eq(:module_state_type)
      expect(stack_type.fields.first.name).to eq("elements")
      expect(stack_type.fields.first.multiplicity).to eq("seq")

      push = document.properties.find { |entity| entity.name == "PushAddsElement" }
      expect(push.kind).to eq(:property)
      expect(push.params.map(&:name)).to eq(["s", "s'", "e"])
      expect(push.normalized_text).to eq("#s'.elements=add[#s.elements,1]")
    end
  end
end
