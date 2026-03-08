# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SpecToPbt::StatefulGenerator config snapshots" do
  let(:snapshot_dir) { File.expand_path("../fixtures/snapshots/stateful_generator_config", __dir__) }

  {
    "stack" => "stack.als",
    "bounded_queue" => "bounded_queue.als",
    "bank_account" => "bank_account.als"
  }.each do |name, fixture_name|
    it "matches the #{name} config snapshot" do
      source = File.read(File.expand_path("../fixtures/alloy/#{fixture_name}", __dir__))
      spec = SpecToPbt::Parser.new.parse(source)
      code = SpecToPbt::StatefulGenerator.new(spec).generate_config
      snapshot_path = File.join(snapshot_dir, "#{name}_config.rb")

      expect(code).to eq(File.read(snapshot_path))
    end
  end
end
