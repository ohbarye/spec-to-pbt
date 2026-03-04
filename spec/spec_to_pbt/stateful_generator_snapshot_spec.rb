# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SpecToPbt::StatefulGenerator snapshots" do
  let(:snapshot_dir) { File.expand_path("../fixtures/snapshots/stateful_generator", __dir__) }

  {
    "stack" => "stack.als",
    "queue" => "queue.als",
    "sort" => "sort.als",
    "workflow_scalar" => "workflow_scalar.als",
    "cache_size_preserving" => "cache_size_preserving.als",
    "bag_body_removal" => "bag_body_removal.als"
  }.each do |name, fixture_name|
    it "matches the #{name} scaffold snapshot" do
      source = File.read(File.expand_path("../fixtures/alloy/#{fixture_name}", __dir__))
      spec = SpecToPbt::Parser.new.parse(source)
      code = SpecToPbt::StatefulGenerator.new(spec).generate
      snapshot_path = File.join(snapshot_dir, "#{name}_scaffold.rb")

      expect(code).to eq(File.read(snapshot_path))
    end
  end
end
