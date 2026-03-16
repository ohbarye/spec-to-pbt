# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"

RSpec.describe "CLI Quint integration", :integration do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:cli_path) { File.join(project_root, "bin/spec_to_pbt") }
  let(:fixture_path) { File.join(project_root, "spec/fixtures/quint/counter.qnt") }
  let(:output_dir) { File.join(project_root, "spec/tmp/quint_integration") }

  before do
    skip "Set SPEC_TO_PBT_RUN_QUINT_INTEGRATION=1 to run live Quint CLI coverage" unless ENV["SPEC_TO_PBT_RUN_QUINT_INTEGRATION"] == "1"
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  it "runs the real Quint CLI end-to-end when opted in" do
    stdout, stderr, status = Open3.capture3(cli_path, fixture_path, "--frontend", "quint", "--stateful", "-o", output_dir)

    expect(status.success?).to be(true), "CLI failed: #{stderr}"
    expect(stdout).to include("Generated:")
    expect(File.exist?(File.join(output_dir, "counter_pbt.rb"))).to be(true)
  end
end
