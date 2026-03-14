# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"

RSpec.describe "Portfolio evaluation" do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:cli_path) { File.join(project_root, "bin/spec_to_pbt") }
  let(:fixtures_dir) { File.join(project_root, "spec/fixtures/alloy") }
  let(:output_dir) { File.join(project_root, "spec/tmp_portfolio_evaluation") }
  let(:pbt_repo_dir) { ENV.fetch("PBT_REPO_DIR", File.expand_path("../pbt", project_root)) }
  let(:pbt_lib_dir) { File.join(pbt_repo_dir, "lib") }

  before do
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  it "validates the fixed portfolio across good implementations and deterministic mutants" do
    skip_unless_local_pbt!

    portfolio_domains.each do |domain|
      domain_dir = File.join(output_dir, domain[:name])
      FileUtils.mkdir_p(domain_dir)

      generate_stateful_with_config!(domain[:fixture], domain_dir)
      File.write(File.join(domain_dir, "#{domain[:name]}_impl.rb"), domain[:good_impl])
      File.write(File.join(domain_dir, "#{domain[:name]}_pbt_config.rb"), domain[:config])

      expect(run_generated_spec("#{domain[:name]}_pbt.rb", domain_dir)).to include("0 failures")

      domain[:mutants].each do |mutant|
        File.write(File.join(domain_dir, "#{domain[:name]}_impl.rb"), mutant[:impl])
        output = run_generated_spec("#{domain[:name]}_pbt.rb", domain_dir, expect_success: mutant[:detected] == false)
        if mutant[:detected]
          expect(output).to include("1 failure"), "Expected mutant #{mutant[:id]} to be detected"
        else
          expect(output).to include("0 failures"), "Expected mutant #{mutant[:id]} to survive"
        end
      end
    end
  end

  private

  def portfolio_domains
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
        mutants: [
          {
            id: "refund_wrong_field",
            detected: true,
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
                  raise "insufficient captured balance" if amount > @captured

                  @authorized -= amount
                  @refunded += amount
                  nil
                end
              end
            RUBY
          },
          {
            id: "refund_allows_over_refund",
            detected: false,
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
          },
          {
            id: "refund_breaks_conservation",
            detected: true,
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
                  raise "insufficient captured balance" if amount > @captured

                  @captured -= amount
                  @refunded += amount + 1
                  nil
                end
              end
            RUBY
          }
        ]
      },
      {
        name: "ledger_projection",
        fixture: "ledger_projection.als",
        good_impl: <<~RUBY,
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
        config: <<~RUBY,
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
        mutants: [
          {
            id: "credit_without_balance_update",
            detected: true,
            impl: <<~RUBY
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
          },
          {
            id: "debit_wrong_direction",
            detected: true,
            impl: <<~RUBY
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
                  @balance += amount
                  nil
                end
              end
            RUBY
          },
          {
            id: "credit_wrong_event_append",
            detected: true,
            impl: <<~RUBY
              # frozen_string_literal: true

              class LedgerProjectionImpl
                attr_reader :entries, :balance

                def initialize(entries: [], balance: 0)
                  @entries = entries.dup
                  @balance = balance
                end

                def post_credit(amount)
                  raise "amount must be positive" if amount <= 0

                  @entries << 0
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
        config: <<~RUBY,
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
        mutants: [
          {
            id: "retry_without_event_append",
            detected: true,
            impl: <<~RUBY
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
          },
          {
            id: "retry_without_budget_consumption",
            detected: true,
            impl: <<~RUBY
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
          },
          {
            id: "deactivate_keeps_status",
            detected: true,
            impl: <<~RUBY
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
        mutants: [
          {
            id: "checkout_wrong_counter",
            detected: true,
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

                  @checked_out -= 1
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
          },
          {
            id: "checkin_without_guard",
            detected: false,
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
          },
          {
            id: "checkout_breaks_capacity_relation",
            detected: true,
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

                  @available -= 2
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
          }
        ]
      }
    ]
  end

  def skip_unless_local_pbt!
    skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)" unless Dir.exist?(pbt_repo_dir)
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
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{pbt_lib_dir}"].compact.join(" ")
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

    "#{stdout}\n#{stderr}"
  end
end
