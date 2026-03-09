# frozen_string_literal: true

require "spec_helper"
require "open3"

PROJECT_ROOT = File.expand_path("../..", __dir__)
EXAMPLE_SPECS = Dir.glob(File.join(PROJECT_ROOT, "example/stateful/*_pbt.rb")).sort

RSpec.describe "Stateful example workflows" do
  let(:project_root) { PROJECT_ROOT }
  let(:pbt_repo_dir) { ENV.fetch("PBT_REPO_DIR", File.expand_path("../pbt", project_root)) }

  it "keeps the example workflow inventory current" do
    basenames = EXAMPLE_SPECS.map { |path| File.basename(path) }

    expect(basenames).to include(
      "stack_pbt.rb",
      "ledger_projection_pbt.rb",
      "feature_flag_rollout_pbt.rb",
      "job_queue_retry_dead_letter_pbt.rb"
    )
  end

  EXAMPLE_SPECS.each do |spec_path|
    basename = File.basename(spec_path)

    it "runs #{basename} against local pbt main" do
      unless Dir.exist?(pbt_repo_dir)
        skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
      end

      env = {
        "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
        "PBT_REPO_DIR" => pbt_repo_dir
      }

      stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", spec_path, chdir: project_root)

      expect(status.success?).to be(true), <<~MSG
        Stateful example workflow failed for #{basename}.
        STDOUT:
        #{stdout}
        STDERR:
        #{stderr}
      MSG
      expect(stdout).to include("1 example")
      expect(stdout).to include("0 failures")
    end
  end
end
