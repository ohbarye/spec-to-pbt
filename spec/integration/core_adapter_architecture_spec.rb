# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Core adapter architecture" do
  let(:adapter) { SpecToPbt::Frontends::Alloy::Adapter.new }
  let(:parser) { SpecToPbt::Parser.new }

  it "produces identical stateless generator output from raw Alloy specs and adapted core docs" do
    source = File.read(File.expand_path("../fixtures/alloy/sort.als", __dir__))
    raw_spec = parser.parse(source)
    core_spec = adapter.adapt(raw_spec)

    expect(SpecToPbt::Generator.new(raw_spec).generate).to eq(SpecToPbt::Generator.new(core_spec).generate)
  end

  it "produces identical stateful generator output from raw Alloy specs and adapted core docs" do
    source = File.read(File.expand_path("../fixtures/alloy/stack.als", __dir__))
    raw_spec = parser.parse(source)
    core_spec = adapter.adapt(raw_spec)

    expect(SpecToPbt::StatefulGenerator.new(raw_spec).generate).to eq(SpecToPbt::StatefulGenerator.new(core_spec).generate)
  end
end
