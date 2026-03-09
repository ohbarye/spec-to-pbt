# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"

RSpec.describe "Stateful regenerated workflows" do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:cli_path) { File.join(project_root, "bin/spec_to_pbt") }
  let(:fixtures_dir) { File.join(project_root, "spec/fixtures/alloy") }
  let(:output_dir) { File.join(project_root, "spec/tmp_stateful_regenerated") }
  let(:pbt_repo_dir) { ENV.fetch("PBT_REPO_DIR", File.expand_path("../pbt", project_root)) }
  let(:pbt_lib_dir) { File.join(pbt_repo_dir, "lib") }

  before do
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  it "runs a regenerated bounded queue workflow with only config and implementation edits" do
    skip_unless_local_pbt!

    generate_stateful_with_config!("bounded_queue.als")

    File.write(File.join(output_dir, "bounded_queue_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class BoundedQueueImpl
        def initialize(capacity: 3)
          @capacity = capacity
          @values = []
        end

        def push_back(value)
          raise "queue is full" if @values.length >= @capacity

          @values << value
          nil
        end

        def shift_front
          raise "queue is empty" if @values.empty?

          @values.shift
        end

        def snapshot
          @values.dup
        end
      end
    RUBY

    File.write(File.join(output_dir, "bounded_queue_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      BoundedQueuePbtConfig = {
        sut_factory: -> { BoundedQueueImpl.new(capacity: 3) },
        command_mappings: {
          enqueue: {
            method: :push_back,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed queue contents to match the model" unless observed_state == after_state[:elements]
            end
          },
          dequeue: {
            method: :shift_front,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed queue contents to match the model" unless observed_state == after_state[:elements]
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { sut.snapshot }
        }
      }
    RUBY

    run_generated_spec!("bounded_queue_pbt.rb")
  end

  it "runs a regenerated bank account workflow with config-driven API remapping" do
    skip_unless_local_pbt!

    generate_stateful_with_config!("bank_account.als")

    File.write(File.join(output_dir, "bank_account_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class BankAccountImpl
        attr_reader :balance

        def initialize
          @balance = 0
        end

        def credit_one
          @balance += 1
          nil
        end

        def credit(amount)
          @balance += amount
          nil
        end

        def debit_one
          raise "insufficient funds" if @balance <= 0

          @balance -= 1
          nil
        end

        def debit(amount)
          raise "insufficient funds" if amount > @balance

          @balance -= amount
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "bank_account_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      BankAccountPbtConfig = {
        sut_factory: -> { BankAccountImpl.new },
        command_mappings: {
          deposit: {
            method: :credit_one,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed balance after credit_one to match model" unless observed_state == after_state
            end
          },
          deposit_amount: {
            method: :credit,
            model_arg_adapter: ->(args) { args.abs + 1 },
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed balance after credit to match model" unless observed_state == after_state
            end
          },
          withdraw: {
            method: :debit_one,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed balance after debit_one to match model" unless observed_state == after_state
            end
          },
          withdraw_amount: {
            method: :debit,
            model_arg_adapter: ->(args) { args.abs + 1 },
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed balance after debit to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { sut.balance }
        }
      }
    RUBY

    run_generated_spec!("bank_account_pbt.rb")
  end

  it "runs a regenerated hold/capture/release workflow with config-driven initial state and observed-state checks" do
    skip_unless_local_pbt!

    generate_stateful_with_config!("hold_capture_release.als")

    File.write(File.join(output_dir, "hold_capture_release_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class HoldCaptureReleaseImpl
        attr_reader :available, :held

        def initialize(available: 10, held: 0)
          @available = available
          @held = held
        end

        def hold(amount)
          raise "insufficient available balance" if amount > @available

          @available -= amount
          @held += amount
          nil
        end

        def capture(amount)
          raise "insufficient held balance" if amount > @held

          @held -= amount
          nil
        end

        def release(amount)
          raise "insufficient held balance" if amount > @held

          @available += amount
          @held -= amount
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "hold_capture_release_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      HoldCaptureReleasePbtConfig = {
        sut_factory: -> { HoldCaptureReleaseImpl.new(available: 10, held: 0) },
        initial_state: { available: 10, held: 0 },
        command_mappings: {
          hold: {
            method: :hold,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed reservation state after hold to match model" unless observed_state == after_state
            end
          },
          capture: {
            method: :capture,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed reservation state after capture to match model" unless observed_state == after_state
            end
          },
          release: {
            method: :release,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed reservation state after release to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { available: sut.available, held: sut.held } }
        }
      }
    RUBY

    run_generated_spec!("hold_capture_release_pbt.rb")
  end

  it "runs a regenerated transfer-between-accounts workflow with config-driven initial state" do
    skip_unless_local_pbt!

    generate_stateful_with_config!("transfer_between_accounts.als")

    File.write(File.join(output_dir, "transfer_between_accounts_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class TransferBetweenAccountsImpl
        attr_reader :source_balance, :target_balance

        def initialize(source_balance: 10, target_balance: 0)
          @source_balance = source_balance
          @target_balance = target_balance
        end

        def transfer(amount)
          raise "insufficient source balance" if amount > @source_balance

          @source_balance -= amount
          @target_balance += amount
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "transfer_between_accounts_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      TransferBetweenAccountsPbtConfig = {
        sut_factory: -> { TransferBetweenAccountsImpl.new(source_balance: 10, target_balance: 0) },
        initial_state: { source_balance: 10, target_balance: 0 },
        command_mappings: {
          transfer: {
            method: :transfer,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed account balances after transfer to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { source_balance: sut.source_balance, target_balance: sut.target_balance } }
        }
      }
    RUBY

    run_generated_spec!("transfer_between_accounts_pbt.rb")
  end

  it "runs a regenerated refund/reversal workflow with config-driven observed-state checks" do
    skip_unless_local_pbt!

    generate_stateful_with_config!("refund_reversal.als")

    File.write(File.join(output_dir, "refund_reversal_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class RefundReversalImpl
        attr_reader :captured, :refunded

        def initialize(captured: 0, refunded: 0)
          @captured = captured
          @refunded = refunded
        end

        def capture(amount)
          raise "amount must be positive" if amount <= 0

          @captured += amount
          nil
        end

        def refund(amount)
          raise "insufficient captured balance" if amount > @captured

          @captured -= amount
          @refunded += amount
          nil
        end

        def reverse(amount)
          raise "insufficient refunded balance" if amount > @refunded

          @captured += amount
          @refunded -= amount
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "refund_reversal_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      RefundReversalPbtConfig = {
        sut_factory: -> { RefundReversalImpl.new },
        initial_state: { captured: 0, refunded: 0 },
        command_mappings: {
          capture: {
            method: :capture,
            model_arg_adapter: ->(args) { args.abs + 1 },
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed settlement state after capture to match model" unless observed_state == after_state
            end
          },
          refund: {
            method: :refund,
            model_arg_adapter: ->(args) { args.abs + 1 },
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed settlement state after refund to match model" unless observed_state == after_state
            end
          },
          reverse: {
            method: :reverse,
            model_arg_adapter: ->(args) { args.abs + 1 },
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed settlement state after reversal to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { captured: sut.captured, refunded: sut.refunded } }
        }
      }
    RUBY

    run_generated_spec!("refund_reversal_pbt.rb")
  end

  it "runs a regenerated ledger projection workflow with config-driven next-state overrides" do
    skip_unless_local_pbt!

    generate_stateful_with_config!("ledger_projection.als")

    File.write(File.join(output_dir, "ledger_projection_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class LedgerProjectionImpl
        attr_reader :entries, :balance

        def initialize(entries: [], balance: 0)
          @entries = entries.dup
          @balance = balance
        end

        def post_credit(amount)
          raise "amount must be positive" if amount <= 0

          @entries << amount
          @balance += amount
          nil
        end

        def post_debit(amount)
          raise "amount must be positive" if amount <= 0

          @entries << -amount
          @balance -= amount
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "ledger_projection_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      LedgerProjectionPbtConfig = {
        sut_factory: -> { LedgerProjectionImpl.new },
        initial_state: { entries: [], balance: 0 },
        command_mappings: {
          post_credit: {
            method: :post_credit,
            model_arg_adapter: ->(args) { args.abs + 1 },
            next_state_override: ->(state, args) do
              delta = args.abs + 1
              { entries: state[:entries] + [delta], balance: state[:balance] + delta }
            end,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed ledger projection after credit to match model" unless observed_state == after_state
            end
          },
          post_debit: {
            method: :post_debit,
            model_arg_adapter: ->(args) { args.abs + 1 },
            next_state_override: ->(state, args) do
              delta = args.abs + 1
              { entries: state[:entries] + [-delta], balance: state[:balance] - delta }
            end,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed ledger projection after debit to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { entries: sut.entries.dup, balance: sut.balance } }
        }
      }
    RUBY

    run_generated_spec!("ledger_projection_pbt.rb")
  end

  it "runs a regenerated rate limiter workflow with config-driven initial state" do
    skip_unless_local_pbt!

    generate_stateful_with_config!("rate_limiter.als")

    File.write(File.join(output_dir, "rate_limiter_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class RateLimiterImpl
        attr_reader :remaining, :capacity

        def initialize(capacity: 3, remaining: capacity)
          @capacity = capacity
          @remaining = remaining
        end

        def allow
          raise "quota exhausted" if @remaining <= 0

          @remaining -= 1
          true
        end

        def reset
          @remaining = @capacity
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "rate_limiter_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      RateLimiterPbtConfig = {
        sut_factory: -> { RateLimiterImpl.new(capacity: 3, remaining: 3) },
        initial_state: { remaining: 3, capacity: 3 },
        command_mappings: {
          allow: {
            method: :allow,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed limiter state after allow to match model" unless observed_state == after_state
            end
          },
          reset: {
            method: :reset,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed limiter state after reset to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { remaining: sut.remaining, capacity: sut.capacity } }
        }
      }
    RUBY

    run_generated_spec!("rate_limiter_pbt.rb")
  end

  it "runs a regenerated connection pool workflow with paired-counter verification" do
    skip_unless_local_pbt!

    generate_stateful_with_config!("connection_pool.als")

    File.write(File.join(output_dir, "connection_pool_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class ConnectionPoolImpl
        attr_reader :available, :checked_out, :capacity

        def initialize(capacity: 3, available: capacity, checked_out: 0)
          @capacity = capacity
          @available = available
          @checked_out = checked_out
        end

        def checkout
          raise "pool exhausted" if @available <= 0

          @available -= 1
          @checked_out += 1
          :connection
        end

        def checkin
          raise "nothing checked out" if @checked_out <= 0

          @available += 1
          @checked_out -= 1
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "connection_pool_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      ConnectionPoolPbtConfig = {
        sut_factory: -> { ConnectionPoolImpl.new(capacity: 3, available: 3, checked_out: 0) },
        initial_state: { available: 3, checked_out: 0, capacity: 3 },
        command_mappings: {
          checkout: {
            method: :checkout,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed pool state after checkout to match model" unless observed_state == after_state
            end
          },
          checkin: {
            method: :checkin,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed pool state after checkin to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { available: sut.available, checked_out: sut.checked_out, capacity: sut.capacity } }
        }
      }
    RUBY

    run_generated_spec!("connection_pool_pbt.rb")
  end

  it "runs a regenerated feature flag rollout workflow with config-driven rollout mapping" do
    skip_unless_local_pbt!

    generate_stateful_with_config!("feature_flag_rollout.als")

    File.write(File.join(output_dir, "feature_flag_rollout_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class FeatureFlagRolloutImpl
        attr_reader :rollout, :max_rollout

        def initialize(max_rollout: 100, rollout: 0)
          @max_rollout = max_rollout
          @rollout = rollout
        end

        def enable_globally
          @rollout = @max_rollout
          nil
        end

        def disable_globally
          @rollout = 0
          nil
        end

        def set_rollout(percent)
          raise "percent must be within rollout bounds" if percent.negative? || percent > @max_rollout

          @rollout = percent
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "feature_flag_rollout_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      FeatureFlagRolloutPbtConfig = {
        sut_factory: -> { FeatureFlagRolloutImpl.new(max_rollout: 100, rollout: 0) },
        initial_state: { rollout: 0, max_rollout: 100 },
        command_mappings: {
          enable: {
            method: :enable_globally,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed rollout state after enable to match model" unless observed_state == after_state
            end
          },
          disable: {
            method: :disable_globally,
            next_state_override: ->(state, _args) { state.merge(rollout: 0) },
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed rollout state after disable to match model" unless observed_state == after_state
            end
          },
          rollout: {
            method: :set_rollout,
            model_arg_adapter: ->(args) { args.abs % 101 },
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed rollout state after set_rollout to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { rollout: sut.rollout, max_rollout: sut.max_rollout } }
        }
      }
    RUBY

    run_generated_spec!("feature_flag_rollout_pbt.rb")
  end

  private

  def skip_unless_local_pbt!
    skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)" unless Dir.exist?(pbt_repo_dir)
  end

  def generate_stateful_with_config!(fixture_name)
    input_file = File.join(fixtures_dir, fixture_name)
    stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)

    expect(status.success?).to be(true), <<~MSG
      CLI generation failed for #{fixture_name}.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
  end

  def run_generated_spec!(generated_filename)
    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{pbt_lib_dir}"].compact.join(" ")
    }

    generated_spec = File.join(output_dir, generated_filename)
    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Regenerated stateful workflow failed for #{generated_filename}.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end
end
