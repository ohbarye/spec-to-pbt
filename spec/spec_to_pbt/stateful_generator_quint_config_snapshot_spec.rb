# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SpecToPbt::StatefulGenerator Quint config snapshots" do
  let(:snapshot_dir) { File.expand_path("../fixtures/snapshots/stateful_generator_config", __dir__) }

  def load_quint_document(name)
    adapter = SpecToPbt::Frontends::Quint::Adapter.new
    parse_path = File.expand_path("../fixtures/quint_json/#{name}_parse.json", __dir__)
    typecheck_path = File.expand_path("../fixtures/quint_json/#{name}_typecheck.json", __dir__)

    adapter.adapt(
      parse_json: JSON.parse(File.read(parse_path)),
      typecheck_json: JSON.parse(File.read(typecheck_path))
    )
  end

  %w[feature_flag_rollout job_queue_retry_dead_letter].each do |name|
    it "matches the #{name} Quint config snapshot" do
      code = SpecToPbt::StatefulGenerator.new(load_quint_document(name)).generate_config
      snapshot_path = File.join(snapshot_dir, "#{name}_quint_config.rb")

      expect(code).to eq(File.read(snapshot_path))
    end
  end
end
