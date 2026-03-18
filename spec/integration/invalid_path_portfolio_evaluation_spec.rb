# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"

RSpec.describe "Invalid-path portfolio evaluation" do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:cli_path) { File.join(project_root, "bin/spec_to_pbt") }
  let(:fixtures_dir) { File.join(project_root, "spec/fixtures/alloy") }
  let(:output_dir) { File.join(project_root, "spec/tmp_invalid_path_portfolio_evaluation") }

  before do
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  it "detects previously surviving invalid-path mutants through config-only workflows" do
    invalid_path_domains.each do |domain|
      domain_dir = File.join(output_dir, domain[:name])
      FileUtils.mkdir_p(domain_dir)

      generate_stateful_with_config!(domain[:fixture], domain_dir)
      File.write(File.join(domain_dir, "#{domain[:name]}_impl.rb"), domain[:good_impl])
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

  def invalid_path_domains
    [
      {
        name: "partial_refund_remaining_capturable",
        fixture: "partial_refund_remaining_capturable.als",
        good_impl: <<~RUBY,
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
        config: <<~RUBY,
          # frozen_string_literal: true

          PartialRefundRemainingCapturablePbtConfig = {
            sut_factory: -> { PartialRefundRemainingCapturableImpl.new(authorized: 20, captured: 0, refunded: 0) },
            initial_state: { authorized: 20, captured: 0, refunded: 0 },
            command_mappings: {
              capture: {
                method: :capture
              },
              refund: {
                method: :refund,
                arguments_override: ->(state) { Pbt.integer(min: state[:captured] + 1, max: state[:captured] + 1) },
                guard_failure_policy: :raise
              }
            },
            verify_context: {
              state_reader: ->(sut) { { authorized: sut.authorized, captured: sut.captured, refunded: sut.refunded } }
            }
          }
        RUBY
        mutants: [
          {
            id: "refund_allows_over_refund",
            impl: <<~RUBY
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
                  @captured -= amount
                  @refunded += amount
                  nil
                end
              end
            RUBY
          }
        ]
      },
      {
        name: "payment_status_amounts",
        fixture: "payment_status_amounts.als",
        good_impl: <<~RUBY,
          # frozen_string_literal: true

          class PaymentStatusAmountsImpl
            attr_reader :status, :authorized_amount, :captured_amount

            def initialize(status: 0, authorized_amount: 0, captured_amount: 0)
              @status = status
              @authorized_amount = authorized_amount
              @captured_amount = captured_amount
            end

            def authorize_amount(amount)
              raise "invalid transition" unless @status == 0
              raise "amount must be positive" unless amount.positive?

              @status = 1
              @authorized_amount += amount
              nil
            end

            def capture_amount(amount)
              raise "invalid transition" unless @status == 1 && amount <= @authorized_amount

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
        config: <<~RUBY,
          # frozen_string_literal: true

          PaymentStatusAmountsPbtConfig = {
            sut_factory: -> { PaymentStatusAmountsImpl.new(status: 0, authorized_amount: 0, captured_amount: 0) },
            initial_state: { status: 0, authorized_amount: 0, captured_amount: 0 },
            command_mappings: {
              authorize_amount: {
                method: :authorize_amount,
                arguments_override: -> { Pbt.integer(min: 1, max: 1) }
              },
              capture_amount: {
                method: :capture_amount,
                arguments_override: ->(state) { Pbt.integer(min: state[:authorized_amount] + 1, max: state[:authorized_amount] + 1) },
                guard_failure_policy: :raise
              },
              reset: {
                method: :reset
              }
            },
            verify_context: {
              state_reader: ->(sut) { { status: sut.status, authorized_amount: sut.authorized_amount, captured_amount: sut.captured_amount } }
            }
          }
        RUBY
        mutants: [
          {
            id: "capture_amount_without_guard",
            impl: <<~RUBY
              # frozen_string_literal: true

              class PaymentStatusAmountsImpl
                attr_reader :status, :authorized_amount, :captured_amount

                def initialize(status: 0, authorized_amount: 0, captured_amount: 0)
                  @status = status
                  @authorized_amount = authorized_amount
                  @captured_amount = captured_amount
                end

                def authorize_amount(amount)
                  raise "invalid transition" unless @status == 0
                  raise "amount must be positive" unless amount.positive?

                  @status = 1
                  @authorized_amount += amount
                  nil
                end

                def capture_amount(amount)
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
          }
        ]
      },
      {
        name: "connection_pool",
        fixture: "connection_pool.als",
        good_impl: <<~RUBY,
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
        config: <<~RUBY,
          # frozen_string_literal: true

          ConnectionPoolPbtConfig = {
            sut_factory: -> { ConnectionPoolImpl.new(capacity: 3, available: 3, checked_out: 0) },
            initial_state: { available: 3, checked_out: 0, capacity: 3 },
            command_mappings: {
              checkout: {
                method: :checkout
              },
              checkin: {
                method: :checkin,
                guard_failure_policy: :raise
              }
            },
            verify_context: {
              state_reader: ->(sut) { { available: sut.available, checked_out: sut.checked_out, capacity: sut.capacity } }
            }
          }
        RUBY
        mutants: [
          {
            id: "checkin_without_guard",
            impl: <<~RUBY
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
                  @available += 1
                  @checked_out -= 1
                  nil
                end
              end
            RUBY
          }
        ]
      },
      {
        name: "job_status_event_counters",
        fixture: "job_status_event_counters.als",
        good_impl: <<~RUBY,
          # frozen_string_literal: true

          class JobStatusEventCountersImpl
            attr_reader :status, :events, :retry_budget, :retry_count

            def initialize(status: 0, events: [], retry_budget: 0, retry_count: 0)
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
        config: <<~RUBY,
          # frozen_string_literal: true

          JobStatusEventCountersPbtConfig = {
            sut_factory: -> { JobStatusEventCountersImpl.new(status: 0, events: [], retry_budget: 0, retry_count: 0) },
            initial_state: { events: [], status: 0, retry_budget: 0, retry_count: 0 },
            command_mappings: {
              activate: {
                method: :activate
              },
              retry: {
                method: :retry,
                guard_failure_policy: :raise
              },
              deactivate: {
                method: :deactivate
              }
            },
            verify_context: {
              state_reader: ->(sut) { { events: sut.events.dup, status: sut.status, retry_budget: sut.retry_budget, retry_count: sut.retry_count } }
            }
          }
        RUBY
        mutants: [
          {
            id: "retry_without_guard",
            impl: <<~RUBY
              # frozen_string_literal: true

              class JobStatusEventCountersImpl
                attr_reader :status, :events, :retry_budget, :retry_count

                def initialize(status: 0, events: [], retry_budget: 0, retry_count: 0)
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
    generated_spec = File.join(domain_dir, generated_filename)
    stdout, stderr, status = Open3.capture3(stateful_pbt_env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

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

    "#{stdout}\n#{stderr}"
  end
end
