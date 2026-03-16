# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"

RSpec.describe "Stateful blind expansion" do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:cli_path) { File.join(project_root, "bin/spec_to_pbt") }
  let(:fixtures_dir) { File.join(project_root, "spec/fixtures/alloy") }
  let(:output_dir) { File.join(project_root, "spec/tmp_stateful_blind_expansion") }

  before do
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  it "keeps the blind 4-domain expansion green with config and impl edits only and detects representative mutants" do

    blind_domains.each do |domain|
      domain_dir = File.join(output_dir, domain[:name])
      FileUtils.mkdir_p(domain_dir)

      generate_stateful_with_config!(domain[:fixture], domain_dir)
      File.write(File.join(domain_dir, "#{domain[:name]}_impl.rb"), File.read(domain[:good_impl_path]))
      File.write(File.join(domain_dir, "#{domain[:name]}_pbt_config.rb"), domain[:config])

      expect(run_generated_spec("#{domain[:name]}_pbt.rb", domain_dir)).to include("0 failures")

      domain[:mutants].each do |mutant|
        File.write(File.join(domain_dir, "#{domain[:name]}_impl.rb"), mutant[:impl])
        output = run_generated_spec("#{domain[:name]}_pbt.rb", domain_dir, expect_success: false)
        expect(output).to include("1 failure"), "Expected mutant #{mutant[:id]} to be detected"
      end
    end
  end

  private

  def blind_domains
    [
      {
        name: "feature_flag_rollout",
        fixture: "feature_flag_rollout.als",
        friction_categories: %w[initial_state observed_state_verification],
        good_impl_path: File.join(project_root, "example/stateful/feature_flag_rollout_impl.rb"),
        config: <<~RUBY,
          # frozen_string_literal: true

          FeatureFlagRolloutPbtConfig = {
            sut_factory: -> { FeatureFlagRolloutImpl.new(max_rollout: 100, rollout: 0) },
            initial_state: { rollout: 0, max_rollout: 100 },
            command_mappings: {
              enable: { method: :enable_globally },
              disable: { method: :disable_globally },
              rollout: { method: :set_rollout }
            },
            verify_context: {
              state_reader: ->(sut) { { rollout: sut.rollout, max_rollout: sut.max_rollout } }
            }
          }
        RUBY
        mutants: [
          {
            id: "enable_sets_wrong_rollout",
            impl: <<~RUBY
              # frozen_string_literal: true

              class FeatureFlagRolloutImpl
                attr_reader :rollout, :max_rollout

                def initialize(max_rollout: 100, rollout: 0)
                  @max_rollout = max_rollout
                  @rollout = rollout
                end

                def enable_globally
                  @rollout = @max_rollout - 1
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
          },
          {
            id: "disable_keeps_rollout",
            impl: <<~RUBY
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
                  nil
                end

                def set_rollout(percent)
                  raise "percent must be within rollout bounds" if percent.negative? || percent > @max_rollout

                  @rollout = percent
                  nil
                end
              end
            RUBY
          }
        ]
      },
      {
        name: "refund_reversal",
        fixture: "refund_reversal.als",
        friction_categories: %w[arg_normalization observed_state_verification],
        good_impl_path: File.join(project_root, "example/stateful/refund_reversal_impl.rb"),
        config: <<~RUBY,
          # frozen_string_literal: true

          RefundReversalPbtConfig = {
            sut_factory: -> { RefundReversalImpl.new },
            initial_state: { captured: 0, refunded: 0 },
            command_mappings: {
              capture: {
                method: :capture,
                model_arg_adapter: ->(args) { args.abs + 1 }
              },
              refund: {
                method: :refund,
                model_arg_adapter: ->(args) { args.abs + 1 }
              },
              reverse: {
                method: :reverse,
                model_arg_adapter: ->(args) { args.abs + 1 }
              }
            },
            verify_context: {
              state_reader: ->(sut) { { captured: sut.captured, refunded: sut.refunded } }
            }
          }
        RUBY
        mutants: [
          {
            id: "refund_wrong_direction",
            impl: <<~RUBY
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
                  raise "amount must be positive" if amount <= 0
                  raise "insufficient captured balance" if amount > @captured

                  @captured += amount
                  @refunded += amount
                  nil
                end

                def reverse(amount)
                  raise "amount must be positive" if amount <= 0
                  raise "insufficient refunded balance" if amount > @refunded

                  @captured += amount
                  @refunded -= amount
                  nil
                end
              end
            RUBY
          },
          {
            id: "reverse_wrong_field",
            impl: <<~RUBY
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
                  raise "amount must be positive" if amount <= 0
                  raise "insufficient captured balance" if amount > @captured

                  @captured -= amount
                  @refunded += amount
                  nil
                end

                def reverse(amount)
                  raise "amount must be positive" if amount <= 0
                  raise "insufficient refunded balance" if amount > @refunded

                  @captured -= amount
                  @refunded -= amount
                  nil
                end
              end
            RUBY
          }
        ]
      },
      {
        name: "inventory_status_projection",
        fixture: "inventory_status_projection.als",
        friction_categories: %w[initial_state observed_state_verification invalid_path_semantics],
        good_impl_path: File.join(project_root, "example/stateful/inventory_status_projection_impl.rb"),
        config: <<~RUBY,
          # frozen_string_literal: true

          InventoryStatusProjectionPbtConfig = {
            sut_factory: -> { InventoryStatusProjectionImpl.new(status: 0, movements: [], stock: 0) },
            initial_state: { movements: [], status: 0, stock: 0 },
            command_mappings: {
              activate: {
                method: :activate,
                guard_failure_policy: :raise
              },
              receive: {
                method: :receive,
                model_arg_adapter: ->(args) { args.abs + 1 },
                guard_failure_policy: :raise
              },
              deactivate: {
                method: :deactivate,
                guard_failure_policy: :raise
              }
            },
            verify_context: {
              state_reader: ->(sut) { { movements: sut.movements.dup, status: sut.status, stock: sut.stock } }
            }
          }
        RUBY
        mutants: [
          {
            id: "receive_without_stock_update",
            impl: <<~RUBY
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
                  nil
                end

                def deactivate
                  raise "invalid transition" unless @status == 1

                  @status = 2
                  nil
                end
              end
            RUBY
          },
          {
            id: "deactivate_keeps_status",
            impl: <<~RUBY
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

                  nil
                end
              end
            RUBY
          }
        ]
      },
      {
        name: "job_queue_retry_dead_letter",
        fixture: "job_queue_retry_dead_letter.als",
        friction_categories: %w[initial_state observed_state_verification],
        good_impl_path: File.join(project_root, "example/stateful/job_queue_retry_dead_letter_impl.rb"),
        config: <<~RUBY,
          # frozen_string_literal: true

          JobQueueRetryDeadLetterPbtConfig = {
            sut_factory: -> { JobQueueRetryDeadLetterImpl.new(ready: 2, in_flight: 0, dead_letter: 0) },
            initial_state: { ready: 2, in_flight: 0, dead_letter: 0 },
            command_mappings: {
              enqueue: { method: :enqueue },
              dispatch: { method: :dispatch },
              ack: { method: :ack },
              retry: { method: :retry },
              dead_letter: { method: :move_to_dead_letter }
            },
            verify_context: {
              state_reader: ->(sut) { { ready: sut.ready, in_flight: sut.in_flight, dead_letter: sut.dead_letter_count } }
            }
          }
        RUBY
        mutants: [
          {
            id: "retry_without_ready_increment",
            impl: <<~RUBY
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
          },
          {
            id: "dead_letter_without_counter",
            impl: <<~RUBY
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
                  nil
                end
              end
            RUBY
          }
        ]
      }
    ]
  end

  def generate_stateful_with_config!(fixture_name, domain_dir)
    input_file = File.join(fixtures_dir, fixture_name)
    stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", domain_dir)

    expect(status.success?).to be(true), <<~MSG
      CLI generation failed for #{fixture_name}.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
  end

  def run_generated_spec(generated_filename, domain_dir, expect_success: true)
    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1"
    }

    generated_spec = File.join(domain_dir, generated_filename)
    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    if expect_success
      expect(status.success?).to be(true), <<~MSG
        Expected generated spec to pass for #{generated_filename}.
        STDOUT:
        #{stdout}
        STDERR:
        #{stderr}
      MSG
    else
      expect(status.success?).to be(false), <<~MSG
        Expected generated spec to fail for #{generated_filename}.
        STDOUT:
        #{stdout}
        STDERR:
        #{stderr}
      MSG
    end

    stdout
  end
end
