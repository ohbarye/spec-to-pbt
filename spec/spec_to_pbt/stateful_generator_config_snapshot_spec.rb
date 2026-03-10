# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SpecToPbt::StatefulGenerator config snapshots" do
  let(:snapshot_dir) { File.expand_path("../fixtures/snapshots/stateful_generator_config", __dir__) }

  {
    "stack" => "stack.als",
    "bounded_queue" => "bounded_queue.als",
    "bank_account" => "bank_account.als",
    "wallet_with_limit" => "wallet_with_limit.als",
    "hold_capture_release" => "hold_capture_release.als",
    "transfer_between_accounts" => "transfer_between_accounts.als",
    "refund_reversal" => "refund_reversal.als",
    "ledger_projection" => "ledger_projection.als",
    "inventory_projection" => "inventory_projection.als",
    "rate_limiter" => "rate_limiter.als",
    "connection_pool" => "connection_pool.als",
    "feature_flag_rollout" => "feature_flag_rollout.als",
    "authorization_expiry_void" => "authorization_expiry_void.als",
    "partial_refund_remaining_capturable" => "partial_refund_remaining_capturable.als",
    "job_queue_retry_dead_letter" => "job_queue_retry_dead_letter.als",
    "payment_status_lifecycle" => "payment_status_lifecycle.als",
    "job_status_lifecycle" => "job_status_lifecycle.als",
    "payment_status_counters" => "payment_status_counters.als",
    "job_status_counters" => "job_status_counters.als",
    "payment_status_amounts" => "payment_status_amounts.als",
    "payout_status_amounts" => "payout_status_amounts.als",
    "payment_status_event_amounts" => "payment_status_event_amounts.als",
    "job_status_event_counters" => "job_status_event_counters.als",
    "ledger_status_projection" => "ledger_status_projection.als",
    "inventory_status_projection" => "inventory_status_projection.als"
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
