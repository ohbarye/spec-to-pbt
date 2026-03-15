# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"

RSpec.describe "Stateful regenerated workflows" do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:cli_path) { File.join(project_root, "bin/spec_to_pbt") }
  let(:fixtures_dir) { File.join(project_root, "spec/fixtures/alloy") }
  let(:output_dir) { File.join(project_root, "spec/tmp_stateful_regenerated") }

  before do
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  it "runs a regenerated bounded queue workflow with only config and implementation edits" do

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

  it "runs a regenerated ledger projection workflow without custom next-state overrides" do

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
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed ledger projection after credit to match model" unless observed_state == after_state
            end
          },
          post_debit: {
            method: :post_debit,
            model_arg_adapter: ->(args) { args.abs + 1 },
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

  it "runs a regenerated inventory projection workflow without custom next-state overrides" do

    generate_stateful_with_config!("inventory_projection.als")

    File.write(File.join(output_dir, "inventory_projection_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class InventoryProjectionImpl
        attr_reader :adjustments, :stock

        def initialize(adjustments: [], stock: 0)
          @adjustments = adjustments.dup
          @stock = stock
        end

        def receive(amount)
          raise "amount must be positive" if amount <= 0

          @adjustments << amount
          @stock += amount
          nil
        end

        def ship(amount)
          raise "amount must be positive" if amount <= 0

          @adjustments << -amount
          @stock -= amount
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "inventory_projection_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      InventoryProjectionPbtConfig = {
        sut_factory: -> { InventoryProjectionImpl.new },
        initial_state: { adjustments: [], stock: 0 },
        command_mappings: {
          receive: {
            method: :receive,
            model_arg_adapter: ->(args) { args.abs + 1 },
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed inventory projection after receive to match model" unless observed_state == after_state
            end
          },
          ship: {
            method: :ship,
            model_arg_adapter: ->(args) { args.abs + 1 },
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed inventory projection after ship to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { adjustments: sut.adjustments.dup, stock: sut.stock } }
        }
      }
    RUBY

    run_generated_spec!("inventory_projection_pbt.rb")
  end

  it "runs a regenerated rate limiter workflow with config-driven initial state" do

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
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed rollout state after disable to match model" unless observed_state == after_state
            end
          },
          rollout: {
            method: :set_rollout,
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

  it "runs a regenerated authorization expiry/void workflow with observed-state verification" do

    generate_stateful_with_config!("authorization_expiry_void.als")

    File.write(File.join(output_dir, "authorization_expiry_void_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class AuthorizationExpiryVoidImpl
        attr_reader :available, :held

        def initialize(available: 20, held: 0)
          @available = available
          @held = held
        end

        def authorize(amount)
          raise "insufficient available balance" if amount > @available

          @available -= amount
          @held += amount
          nil
        end

        def void_authorization(amount)
          raise "insufficient held balance" if amount > @held

          @available += amount
          @held -= amount
          nil
        end

        def expire_authorization(amount)
          raise "insufficient held balance" if amount > @held

          @available += amount
          @held -= amount
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "authorization_expiry_void_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      AuthorizationExpiryVoidPbtConfig = {
        sut_factory: -> { AuthorizationExpiryVoidImpl.new(available: 20, held: 0) },
        initial_state: { available: 20, held: 0 },
        command_mappings: {
          authorize: {
            method: :authorize,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed authorization state after authorize to match model" unless observed_state == after_state
            end
          },
          void: {
            method: :void_authorization,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed authorization state after void to match model" unless observed_state == after_state
            end
          },
          expire: {
            method: :expire_authorization,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed authorization state after expiry to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { available: sut.available, held: sut.held } }
        }
      }
    RUBY

    run_generated_spec!("authorization_expiry_void_pbt.rb")
  end

  it "runs a regenerated partial refund workflow with three-field payment state" do

    generate_stateful_with_config!("partial_refund_remaining_capturable.als")

    File.write(File.join(output_dir, "partial_refund_remaining_capturable_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class PartialRefundRemainingCapturableImpl
        attr_reader :authorized, :captured, :refunded

        def initialize(authorized: 20, captured: 0, refunded: 0)
          @authorized = authorized
          @captured = captured
          @refunded = refunded
        end

        def capture(amount)
          raise "insufficient authorized balance" if amount > @authorized

          @authorized -= amount
          @captured += amount
          nil
        end

        def refund(amount)
          raise "insufficient captured balance" if amount > @captured

          @captured -= amount
          @refunded += amount
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "partial_refund_remaining_capturable_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      PartialRefundRemainingCapturablePbtConfig = {
        sut_factory: -> { PartialRefundRemainingCapturableImpl.new(authorized: 20, captured: 0, refunded: 0) },
        initial_state: { authorized: 20, captured: 0, refunded: 0 },
        command_mappings: {
          capture: {
            method: :capture,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment state after capture to match model" unless observed_state == after_state
            end
          },
          refund: {
            method: :refund,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment state after refund to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { authorized: sut.authorized, captured: sut.captured, refunded: sut.refunded } }
        }
      }
    RUBY

    run_generated_spec!("partial_refund_remaining_capturable_pbt.rb")
  end

  it "runs a regenerated job queue retry/dead-letter workflow with observed-state verification" do

    generate_stateful_with_config!("job_queue_retry_dead_letter.als")

    File.write(File.join(output_dir, "job_queue_retry_dead_letter_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class JobQueueRetryDeadLetterImpl
        attr_reader :ready, :in_flight, :dead_letter_count

        def initialize(ready: 2, in_flight: 0, dead_letter: 0)
          @ready = ready
          @in_flight = in_flight
          @dead_letter_count = dead_letter
        end

        def enqueue
          @ready += 1
          nil
        end

        def dispatch
          raise "no ready jobs" if @ready <= 0

          @ready -= 1
          @in_flight += 1
          :job
        end

        def ack
          raise "no in-flight jobs" if @in_flight <= 0

          @in_flight -= 1
          nil
        end

        def retry
          raise "no in-flight jobs" if @in_flight <= 0

          @in_flight -= 1
          @ready += 1
          nil
        end

        def move_to_dead_letter
          raise "no in-flight jobs" if @in_flight <= 0

          @in_flight -= 1
          @dead_letter_count += 1
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "job_queue_retry_dead_letter_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      JobQueueRetryDeadLetterPbtConfig = {
        sut_factory: -> { JobQueueRetryDeadLetterImpl.new(ready: 2, in_flight: 0, dead_letter: 0) },
        initial_state: { ready: 2, in_flight: 0, dead_letter: 0 },
        command_mappings: {
          enqueue: {
            method: :enqueue,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job queue state after enqueue to match model" unless observed_state == after_state
            end
          },
          dispatch: {
            method: :dispatch,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job queue state after dispatch to match model" unless observed_state == after_state
            end
          },
          ack: {
            method: :ack,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job queue state after ack to match model" unless observed_state == after_state
            end
          },
          retry: {
            method: :retry,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job queue state after retry to match model" unless observed_state == after_state
            end
          },
          dead_letter: {
            method: :move_to_dead_letter,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job queue state after dead-letter to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { ready: sut.ready, in_flight: sut.in_flight, dead_letter: sut.dead_letter_count } }
        }
      }
    RUBY

    run_generated_spec!("job_queue_retry_dead_letter_pbt.rb")
  end

  it "runs a regenerated payment status lifecycle workflow with invalid-transition raise semantics" do

    generate_stateful_with_config!("payment_status_lifecycle.als")

    File.write(File.join(output_dir, "payment_status_lifecycle_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class PaymentStatusLifecycleImpl
        attr_reader :status

        def initialize(status: 0)
          @status = status
        end

        def authorize
          raise "invalid transition" unless @status == 0

          @status = 1
          nil
        end

        def capture
          raise "invalid transition" unless @status == 1

          @status = 2
          nil
        end

        def void
          raise "invalid transition" unless @status == 1

          @status = 3
          nil
        end

        def refund
          raise "invalid transition" unless @status == 2

          @status = 4
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "payment_status_lifecycle_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      PaymentStatusLifecyclePbtConfig = {
        sut_factory: -> { PaymentStatusLifecycleImpl.new(status: 0) },
        initial_state: 0,
        command_mappings: {
          authorize: {
            method: :authorize,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment status after authorize to match model" unless observed_state == after_state
            end
          },
          capture: {
            method: :capture,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment status after capture to match model" unless observed_state == after_state
            end
          },
          void: {
            method: :void,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment status after void to match model" unless observed_state == after_state
            end
          },
          refund: {
            method: :refund,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment status after refund to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { sut.status }
        }
      }
    RUBY

    run_generated_spec!("payment_status_lifecycle_pbt.rb")
  end

  it "runs a regenerated job status lifecycle workflow with method remapping and invalid-transition raise semantics" do

    generate_stateful_with_config!("job_status_lifecycle.als")

    File.write(File.join(output_dir, "job_status_lifecycle_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class JobStatusLifecycleImpl
        attr_reader :status

        def initialize(status: 0)
          @status = status
        end

        def start
          raise "invalid transition" unless @status == 0

          @status = 1
          nil
        end

        def complete
          raise "invalid transition" unless @status == 1

          @status = 2
          nil
        end

        def mark_failed
          raise "invalid transition" unless @status == 1

          @status = 3
          nil
        end

        def move_to_dead_letter
          raise "invalid transition" unless @status == 3

          @status = 4
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "job_status_lifecycle_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      JobStatusLifecyclePbtConfig = {
        sut_factory: -> { JobStatusLifecycleImpl.new(status: 0) },
        initial_state: 0,
        command_mappings: {
          start: {
            method: :start,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job status after start to match model" unless observed_state == after_state
            end
          },
          complete: {
            method: :complete,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job status after complete to match model" unless observed_state == after_state
            end
          },
          fail: {
            method: :mark_failed,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job status after fail to match model" unless observed_state == after_state
            end
          },
          dead_letter: {
            method: :move_to_dead_letter,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job status after dead-letter to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { sut.status }
        }
      }
    RUBY

    run_generated_spec!("job_status_lifecycle_pbt.rb")
  end

  it "runs a regenerated payment status+counters workflow with mixed constant and counter updates" do

    generate_stateful_with_config!("payment_status_counters.als")

    File.write(File.join(output_dir, "payment_status_counters_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class PaymentStatusCountersImpl
        attr_reader :status, :authorized, :captured

        def initialize(status: 0, authorized: 0, captured: 0)
          @status = status
          @authorized = authorized
          @captured = captured
        end

        def authorize_one
          raise "invalid transition" unless @status == 0

          @status = 1
          @authorized += 1
          nil
        end

        def capture_one
          raise "invalid transition" unless @status == 1 && @authorized.positive?

          @status = 2
          @authorized -= 1
          @captured += 1
          nil
        end

        def reset
          raise "invalid transition" unless @status == 2

          @status = 0
          @authorized = 0
          @captured = 0
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "payment_status_counters_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      PaymentStatusCountersPbtConfig = {
        sut_factory: -> { PaymentStatusCountersImpl.new(status: 0, authorized: 0, captured: 0) },
        initial_state: { status: 0, authorized: 0, captured: 0 },
        command_mappings: {
          authorize_one: {
            method: :authorize_one,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment counters after authorize_one to match model" unless observed_state == after_state
            end
          },
          capture_one: {
            method: :capture_one,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment counters after capture_one to match model" unless observed_state == after_state
            end
          },
          reset: {
            method: :reset,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment counters after reset to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { status: sut.status, authorized: sut.authorized, captured: sut.captured } }
        }
      }
    RUBY

    run_generated_spec!("payment_status_counters_pbt.rb")
  end

  it "runs a regenerated job status+counters workflow with method remapping" do

    generate_stateful_with_config!("job_status_counters.als")

    File.write(File.join(output_dir, "job_status_counters_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class JobStatusCountersImpl
        attr_reader :status, :retry_count, :dead_letter_count

        def initialize(status: 0, retry_count: 0, dead_letter_count: 0)
          @status = status
          @retry_count = retry_count
          @dead_letter_count = dead_letter_count
        end

        def dispatch
          raise "invalid transition" unless @status == 0

          @status = 1
          nil
        end

        def requeue
          raise "invalid transition" unless @status == 1

          @status = 0
          @retry_count += 1
          nil
        end

        def move_to_dead_letter
          raise "invalid transition" unless @status == 1

          @status = 2
          @dead_letter_count += 1
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "job_status_counters_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      JobStatusCountersPbtConfig = {
        sut_factory: -> { JobStatusCountersImpl.new(status: 0, retry_count: 0, dead_letter_count: 0) },
        initial_state: { status: 0, retry_count: 0, dead_letter_count: 0 },
        command_mappings: {
          start: {
            method: :dispatch,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job counters after start to match model" unless observed_state == after_state
            end
          },
          retry: {
            method: :requeue,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job counters after retry to match model" unless observed_state == after_state
            end
          },
          dead_letter: {
            method: :move_to_dead_letter,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job counters after dead_letter to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { status: sut.status, retry_count: sut.retry_count, dead_letter_count: sut.dead_letter_count } }
        }
      }
    RUBY

    run_generated_spec!("job_status_counters_pbt.rb")
  end

  it "runs a regenerated payment status+amount workflow with observed-state verification" do

    generate_stateful_with_config!("payment_status_amounts.als")

    File.write(File.join(output_dir, "payment_status_amounts_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class PaymentStatusAmountsImpl
        attr_reader :status, :authorized_amount, :captured_amount

        def initialize(status: 0, authorized_amount: 0, captured_amount: 0)
          @status = status
          @authorized_amount = authorized_amount
          @captured_amount = captured_amount
        end

        def authorize_amount(amount)
          raise "invalid transition" unless @status == 0 && amount.positive?

          @status = 1
          @authorized_amount += amount
          nil
        end

        def capture_amount(amount)
          raise "invalid transition" unless @status == 1 && amount.positive? && amount <= @authorized_amount

          @status = 2
          @authorized_amount -= amount
          @captured_amount += amount
          nil
        end

        def reset
          raise "invalid transition" unless @status == 2

          @status = 0
          @authorized_amount = 0
          @captured_amount = 0
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "payment_status_amounts_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      PaymentStatusAmountsPbtConfig = {
        sut_factory: -> { PaymentStatusAmountsImpl.new(status: 0, authorized_amount: 0, captured_amount: 0) },
        initial_state: { status: 0, authorized_amount: 0, captured_amount: 0 },
        command_mappings: {
          authorize_amount: {
            method: :authorize_amount,
            model_arg_adapter: ->(args) { args.abs + 1 },
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment amounts after authorize_amount to match model" unless observed_state == after_state
            end
          },
          capture_amount: {
            method: :capture_amount,
            model_arg_adapter: ->(args) { args.abs + 1 },
            applicable_override: ->(state, args) { state[:status] == 1 && args.abs + 1 <= state[:authorized_amount] },
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment amounts after capture_amount to match model" unless observed_state == after_state
            end
          },
          reset: {
            method: :reset,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment amounts after reset to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { status: sut.status, authorized_amount: sut.authorized_amount, captured_amount: sut.captured_amount } }
        }
      }
    RUBY

    run_generated_spec!("payment_status_amounts_pbt.rb")
  end

  it "runs a regenerated payout status+amount workflow with observed-state verification" do

    generate_stateful_with_config!("payout_status_amounts.als")

    File.write(File.join(output_dir, "payout_status_amounts_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class PayoutStatusAmountsImpl
        attr_reader :status, :pending_amount, :paid_amount

        def initialize(status: 0, pending_amount: 0, paid_amount: 0)
          @status = status
          @pending_amount = pending_amount
          @paid_amount = paid_amount
        end

        def queue_amount(amount)
          raise "invalid transition" unless @status == 0 && amount.positive?

          @status = 1
          @pending_amount += amount
          nil
        end

        def complete_amount(amount)
          raise "invalid transition" unless @status == 1 && amount.positive? && amount <= @pending_amount

          @status = 2
          @pending_amount -= amount
          @paid_amount += amount
          nil
        end

        def reset
          raise "invalid transition" unless @status == 2

          @status = 0
          @pending_amount = 0
          @paid_amount = 0
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "payout_status_amounts_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      PayoutStatusAmountsPbtConfig = {
        sut_factory: -> { PayoutStatusAmountsImpl.new(status: 0, pending_amount: 0, paid_amount: 0) },
        initial_state: { status: 0, pending_amount: 0, paid_amount: 0 },
        command_mappings: {
          queue_amount: {
            method: :queue_amount,
            model_arg_adapter: ->(args) { args.abs + 1 },
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payout amounts after queue_amount to match model" unless observed_state == after_state
            end
          },
          complete_amount: {
            method: :complete_amount,
            model_arg_adapter: ->(args) { args.abs + 1 },
            applicable_override: ->(state, args) { state[:status] == 1 && args.abs + 1 <= state[:pending_amount] },
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payout amounts after complete_amount to match model" unless observed_state == after_state
            end
          },
          reset: {
            method: :reset,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payout amounts after reset to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { status: sut.status, pending_amount: sut.pending_amount, paid_amount: sut.paid_amount } }
        }
      }
    RUBY

    run_generated_spec!("payout_status_amounts_pbt.rb")
  end

  it "runs a regenerated ledger status+projection workflow with observed-state verification" do

    generate_stateful_with_config!("ledger_status_projection.als")

    File.write(File.join(output_dir, "ledger_status_projection_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class LedgerStatusProjectionImpl
        attr_reader :status, :entries, :balance

        def initialize(status: 0, entries: [], balance: 0)
          @status = status
          @entries = entries.dup
          @balance = balance
        end

        def open
          raise "invalid transition" unless @status == 0

          @status = 1
          nil
        end

        def post_amount(amount)
          raise "invalid transition" unless @status == 1 && amount.positive?

          @entries << amount
          @balance += amount
          nil
        end

        def close
          raise "invalid transition" unless @status == 1

          @status = 2
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "ledger_status_projection_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      LedgerStatusProjectionPbtConfig = {
        sut_factory: -> { LedgerStatusProjectionImpl.new(status: 0, entries: [], balance: 0) },
        initial_state: { entries: [], status: 0, balance: 0 },
        command_mappings: {
          open: {
            method: :open,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed ledger projection state after open to match model" unless observed_state == after_state
            end
          },
          post_amount: {
            method: :post_amount,
            model_arg_adapter: ->(args) { args.abs + 1 },
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed ledger projection state after post_amount to match model" unless observed_state == after_state
            end
          },
          close: {
            method: :close,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed ledger projection state after close to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { entries: sut.entries.dup, status: sut.status, balance: sut.balance } }
        }
      }
    RUBY

    run_generated_spec!("ledger_status_projection_pbt.rb")
  end

  it "runs a regenerated inventory status+projection workflow with observed-state verification" do

    generate_stateful_with_config!("inventory_status_projection.als")

    File.write(File.join(output_dir, "inventory_status_projection_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class InventoryStatusProjectionImpl
        attr_reader :status, :movements, :stock

        def initialize(status: 0, movements: [], stock: 0)
          @status = status
          @movements = movements.dup
          @stock = stock
        end

        def activate
          raise "invalid transition" unless @status == 0

          @status = 1
          nil
        end

        def receive(amount)
          raise "invalid transition" unless @status == 1 && amount.positive?

          @movements << amount
          @stock += amount
          nil
        end

        def deactivate
          raise "invalid transition" unless @status == 1

          @status = 2
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "inventory_status_projection_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      InventoryStatusProjectionPbtConfig = {
        sut_factory: -> { InventoryStatusProjectionImpl.new(status: 0, movements: [], stock: 0) },
        initial_state: { movements: [], status: 0, stock: 0 },
        command_mappings: {
          activate: {
            method: :activate,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed inventory projection state after activate to match model" unless observed_state == after_state
            end
          },
          receive: {
            method: :receive,
            model_arg_adapter: ->(args) { args.abs + 1 },
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed inventory projection state after receive to match model" unless observed_state == after_state
            end
          },
          deactivate: {
            method: :deactivate,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed inventory projection state after deactivate to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { movements: sut.movements.dup, status: sut.status, stock: sut.stock } }
        }
      }
    RUBY

    run_generated_spec!("inventory_status_projection_pbt.rb")
  end

  it "runs a regenerated payment status+event+amount workflow with observed-state verification" do

    generate_stateful_with_config!("payment_status_event_amounts.als")

    File.write(File.join(output_dir, "payment_status_event_amounts_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class PaymentStatusEventAmountsImpl
        attr_reader :status, :captures, :remaining_amount, :settled_amount

        def initialize(status: 0, captures: [], remaining_amount: 3, settled_amount: 0)
          @status = status
          @captures = captures.dup
          @remaining_amount = remaining_amount
          @settled_amount = settled_amount
        end

        def open
          raise "invalid transition" unless @status == 0

          @status = 1
          nil
        end

        def settle_unit
          raise "invalid transition" unless @status == 1 && @remaining_amount.positive?

          @captures << 1
          @remaining_amount -= 1
          @settled_amount += 1
          nil
        end

        def close
          raise "invalid transition" unless @status == 1

          @status = 2
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "payment_status_event_amounts_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      PaymentStatusEventAmountsPbtConfig = {
        sut_factory: -> { PaymentStatusEventAmountsImpl.new(status: 0, captures: [], remaining_amount: 3, settled_amount: 0) },
        initial_state: { captures: [], status: 0, remaining_amount: 3, settled_amount: 0 },
        command_mappings: {
          open: {
            method: :open,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment event state after open to match model" unless observed_state == after_state
            end
          },
          settle_unit: {
            method: :settle_unit,
            applicable_override: ->(state, _args = nil) { state[:status] == 1 && state[:remaining_amount] > 0 },
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment event state after settle_unit to match model" unless observed_state == after_state
            end
          },
          close: {
            method: :close,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed payment event state after close to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { captures: sut.captures.dup, status: sut.status, remaining_amount: sut.remaining_amount, settled_amount: sut.settled_amount } }
        }
      }
    RUBY

    run_generated_spec!("payment_status_event_amounts_pbt.rb")
  end

  it "runs a regenerated job status+event+counter workflow with observed-state verification" do

    generate_stateful_with_config!("job_status_event_counters.als")

    File.write(File.join(output_dir, "job_status_event_counters_impl.rb"), <<~RUBY)
      # frozen_string_literal: true

      class JobStatusEventCountersImpl
        attr_reader :status, :events, :retry_budget, :retry_count

        def initialize(status: 0, events: [], retry_budget: 3, retry_count: 0)
          @status = status
          @events = events.dup
          @retry_budget = retry_budget
          @retry_count = retry_count
        end

        def activate
          raise "invalid transition" unless @status == 0

          @status = 1
          nil
        end

        def retry
          raise "invalid transition" unless @status == 1 && @retry_budget.positive?

          @events << 1
          @retry_budget -= 1
          @retry_count += 1
          nil
        end

        def deactivate
          raise "invalid transition" unless @status == 1

          @status = 2
          nil
        end
      end
    RUBY

    File.write(File.join(output_dir, "job_status_event_counters_pbt_config.rb"), <<~RUBY)
      # frozen_string_literal: true

      JobStatusEventCountersPbtConfig = {
        sut_factory: -> { JobStatusEventCountersImpl.new(status: 0, events: [], retry_budget: 3, retry_count: 0) },
        initial_state: { events: [], status: 0, retry_budget: 3, retry_count: 0 },
        command_mappings: {
          activate: {
            method: :activate,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job event state after activate to match model" unless observed_state == after_state
            end
          },
          retry: {
            method: :retry,
            applicable_override: ->(state, _args = nil) { state[:status] == 1 && state[:retry_budget] > 0 },
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job event state after retry to match model" unless observed_state == after_state
            end
          },
          deactivate: {
            method: :deactivate,
            guard_failure_policy: :raise,
            verify_override: ->(after_state:, observed_state:, **) do
              raise "Expected observed job event state after deactivate to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { { events: sut.events.dup, status: sut.status, retry_budget: sut.retry_budget, retry_count: sut.retry_count } }
        }
      }
    RUBY

    run_generated_spec!("job_status_event_counters_pbt.rb")
  end

  private

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
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1"
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
