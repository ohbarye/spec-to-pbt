# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe "Stateful example workflows" do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:pbt_repo_dir) { ENV.fetch("PBT_REPO_DIR", File.expand_path("../pbt", project_root)) }

  it "runs the bounded queue example against local pbt main" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "PBT_REPO_DIR" => pbt_repo_dir
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", "example/stateful/bounded_queue_pbt.rb", chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Bounded queue example workflow failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "runs the bank account example against local pbt main" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "PBT_REPO_DIR" => pbt_repo_dir
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", "example/stateful/bank_account_pbt.rb", chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Bank account example workflow failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "runs the hold/capture/release example against local pbt main" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "PBT_REPO_DIR" => pbt_repo_dir
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", "example/stateful/hold_capture_release_pbt.rb", chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Hold/capture/release example workflow failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "runs the transfer-between-accounts example against local pbt main" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "PBT_REPO_DIR" => pbt_repo_dir
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", "example/stateful/transfer_between_accounts_pbt.rb", chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Transfer-between-accounts example workflow failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "runs the refund/reversal example against local pbt main" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "PBT_REPO_DIR" => pbt_repo_dir
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", "example/stateful/refund_reversal_pbt.rb", chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Refund/reversal example workflow failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "runs the ledger projection example against local pbt main" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "PBT_REPO_DIR" => pbt_repo_dir
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", "example/stateful/ledger_projection_pbt.rb", chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Ledger projection example workflow failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "runs the rate limiter example against local pbt main" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "PBT_REPO_DIR" => pbt_repo_dir
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", "example/stateful/rate_limiter_pbt.rb", chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Rate limiter example workflow failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "runs the connection pool example against local pbt main" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "PBT_REPO_DIR" => pbt_repo_dir
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", "example/stateful/connection_pool_pbt.rb", chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Connection pool example workflow failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "runs the feature flag rollout example against local pbt main" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "PBT_REPO_DIR" => pbt_repo_dir
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", "example/stateful/feature_flag_rollout_pbt.rb", chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Feature flag rollout example workflow failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end
end
