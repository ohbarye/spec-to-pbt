# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"

RSpec.describe "Stateful scaffold contract" do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:cli_path) { File.join(project_root, "bin/spec_to_pbt") }
  let(:fixtures_dir) { File.join(project_root, "spec/fixtures/alloy") }
  let(:output_dir) { File.join(project_root, "spec/tmp_stateful_contract") }
  let(:stub_lib_dir) { File.join(output_dir, "stub_lib") }

  before do
    FileUtils.mkdir_p(output_dir)
    FileUtils.mkdir_p(stub_lib_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  it "matches the expected Pbt.stateful API and command protocol used against pbt main" do
    input_file = File.join(fixtures_dir, "stack.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "stack_pbt.rb")
    impl_file = File.join(output_dir, "stack_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(impl_file, <<~RUBY)
      # frozen_string_literal: true

      class StackImpl
        def initialize
          @values = []
        end

        def push_adds_element(value)
          @values << value
          nil
        end

        def pop_removes_element
          @values.pop
        end
      end
    RUBY

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
        class << self
          attr_reader :last_stateful_call
        end

        define_singleton_method(:nil) { nil }

        def self.integer = 1
        def self.string = "x"
        def self.array(value) = [value]
        def self.tuple(*values) = values

        def self.assert(worker:, num_runs:, seed:)
          raise "unexpected assert kwargs" unless worker == :none && num_runs == 5 && seed == 1

          yield
        end

        def self.command_arguments(command, state)
          parameters = command.method(:arguments).parameters
          if parameters.any? { |kind, _name| kind == :req }
            command.arguments(state)
          else
            command.arguments
          end
        end

        def self.command_applicable?(command, state, args)
          parameters = command.method(:applicable?).parameters
          required = parameters.count { |kind, _name| kind == :req }
          required >= 2 ? command.applicable?(state, args) : command.applicable?(state)
        end

        def self.stateful(model:, sut:, max_steps:, **extra)
          raise "unexpected Pbt.stateful kwargs: \#{extra.keys.inspect}" unless extra.empty?
          raise "model missing initial_state" unless model.respond_to?(:initial_state)
          raise "model missing commands" unless model.respond_to?(:commands)
          raise "sut factory must be callable" unless sut.respond_to?(:call)
          raise "max_steps must be Integer" unless max_steps.is_a?(Integer)

          state = model.initial_state
          commands = model.commands(state)
          raise "commands must be an array" unless commands.is_a?(Array)
          raise "commands must not be empty" if commands.empty?

          command = commands.first
          required_methods = %i[name arguments applicable? next_state run! verify!]
          missing = required_methods.reject { |m| command.respond_to?(m) }
          raise "command protocol mismatch: \#{missing.inspect}" unless missing.empty?

          args = command_arguments(command, state)
          applicable = command_applicable?(command, state, args)
          before_state = state
          after_state = command.next_state(state, args)
          result = applicable ? command.run!(sut.call, args) : nil
          command.verify!(before_state:, after_state:, args:, result:, sut: sut.call)

          @last_stateful_call = {
            command_name: command.name,
            args: args,
            max_steps: max_steps
          }
        end
      end
    RUBY

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Generated scaffold contract run failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "respects config-driven Ruby API remapping" do
    input_file = File.join(fixtures_dir, "stack.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "stack_pbt.rb")
    config_file = File.join(output_dir, "stack_pbt_config.rb")
    impl_file = File.join(output_dir, "stack_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(impl_file, <<~RUBY)
      # frozen_string_literal: true

      class StackImpl
        def initialize
          @values = []
        end

        def push(value)
          @values << value
          nil
        end

        def pop
          @values.pop
        end
      end
    RUBY

    File.write(config_file, <<~RUBY)
      # frozen_string_literal: true

      StackPbtConfig = {
        sut_factory: -> { StackImpl.new },
        command_mappings: {
          push_adds_element: { method: :push },
          pop_removes_element: { method: :pop }
        },
        verify_context: {
          state_reader: nil
        }
      }
    RUBY

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
        define_singleton_method(:nil) { nil }

        def self.integer = 1
        def self.string = "x"
        def self.array(value) = [value]
        def self.tuple(*values) = values

        def self.assert(worker:, num_runs:, seed:)
          raise "unexpected assert kwargs" unless worker == :none && num_runs == 5 && seed == 1

          yield
        end

        def self.command_arguments(command, state)
          parameters = command.method(:arguments).parameters
          if parameters.any? { |kind, _name| kind == :req }
            command.arguments(state)
          else
            command.arguments
          end
        end

        def self.stateful(model:, sut:, max_steps:, **extra)
          raise "unexpected Pbt.stateful kwargs: \#{extra.keys.inspect}" unless extra.empty?

          state = model.initial_state
          command = model.commands(state).first
          args = command_arguments(command, state)
          after_state = command.next_state(state, args)
          result = command.run!(sut.call, args)
          command.verify!(before_state: state, after_state: after_state, args: args, result: result, sut: sut.call)
        end
      end
    RUBY

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Generated config-aware scaffold contract run failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "passes observed_state into verify_override via state_reader" do
    input_file = File.join(fixtures_dir, "stack.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "stack_pbt.rb")
    config_file = File.join(output_dir, "stack_pbt_config.rb")
    impl_file = File.join(output_dir, "stack_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(impl_file, <<~RUBY)
      # frozen_string_literal: true

      class StackImpl
        def initialize
          @values = []
        end

        def push(value)
          @values << value
          nil
        end

        def pop
          @values.pop
        end

        def snapshot
          @values.dup
        end
      end
    RUBY

    File.write(config_file, <<~RUBY)
      # frozen_string_literal: true

      StackPbtConfig = {
        sut_factory: -> { StackImpl.new },
        command_mappings: {
          push_adds_element: {
            method: :push,
            verify_override: ->(after_state:, observed_state:) do
              raise "Expected observed_state keyword" if observed_state.nil?
              raise "Expected observed push state to match model" unless observed_state == after_state
            end
          },
          pop_removes_element: {
            method: :pop,
            verify_override: ->(after_state:, observed_state:) do
              raise "Expected observed_state keyword" if observed_state.nil?
              raise "Expected observed pop state to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { sut.snapshot }
        }
      }
    RUBY

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
        define_singleton_method(:nil) { nil }

        def self.integer = 1
        def self.string = "x"
        def self.array(value) = [value]
        def self.tuple(*values) = values

        def self.assert(worker:, num_runs:, seed:)
          raise "unexpected assert kwargs" unless worker == :none && num_runs == 5 && seed == 1

          yield
        end

        def self.command_arguments(command, state)
          parameters = command.method(:arguments).parameters
          if parameters.any? { |kind, _name| kind == :req }
            command.arguments(state)
          else
            command.arguments
          end
        end

        def self.stateful(model:, sut:, max_steps:, **extra)
          raise "unexpected Pbt.stateful kwargs: \#{extra.keys.inspect}" unless extra.empty?

          state = model.initial_state
          command = model.commands(state).first
          args = command_arguments(command, state)
          before_sut = sut.call
          after_state = command.next_state(state, args)
          result = command.run!(before_sut, args)
          command.verify!(before_state: state, after_state: after_state, args: args, result: result, sut: before_sut)
        end
      end
    RUBY

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Generated scaffold with state_reader-backed verify_override failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "supports config-driven no-op guard failure handling" do
    input_file = File.join(fixtures_dir, "bank_account.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "bank_account_pbt.rb")
    config_file = File.join(output_dir, "bank_account_pbt_config.rb")
    impl_file = File.join(output_dir, "bank_account_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(impl_file, <<~RUBY)
      # frozen_string_literal: true

      class BankAccountImpl
        attr_reader :balance

        def initialize
          @balance = 0
        end

        def withdraw(amount)
          @balance -= amount if amount <= @balance
          @balance
        end
      end
    RUBY

    File.write(config_file, <<~RUBY)
      # frozen_string_literal: true

      BankAccountPbtConfig = {
        sut_factory: -> { BankAccountImpl.new },
        initial_state: 0,
        command_mappings: {
          withdraw_amount: {
            method: :withdraw,
            guard_failure_policy: :no_op
          }
        },
        verify_context: {
          state_reader: ->(sut) { sut.balance }
        }
      }
    RUBY

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
        define_singleton_method(:nil) { nil }

        def self.integer(**_kwargs) = 1
        def self.string = "x"
        def self.array(value) = [value]
        def self.tuple(*values) = values

        def self.assert(worker:, num_runs:, seed:)
          raise "unexpected assert kwargs" unless worker == :none && num_runs == 5 && seed == 1

          yield
        end

        def self.stateful(model:, sut:, max_steps:, **extra)
          raise "unexpected Pbt.stateful kwargs: \#{extra.keys.inspect}" unless extra.empty?
          raise "unexpected max_steps" unless max_steps == 20

          state = model.initial_state
          command = model.commands(state).find { |candidate| candidate.name == :withdraw_amount }
          raise "withdraw_amount command missing" unless command

          args = command.arguments(state)
          raise "guard failure policy should keep command applicable" unless command.applicable?(state, args)

          instance = sut.call
          after_state = command.next_state(state, args)
          result = command.run!(instance, args)
          command.verify!(before_state: state, after_state: after_state, args: args, result: result, sut: instance)
        end
      end
    RUBY

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Generated scaffold with no-op guard failure handling failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "supports config-driven raising guard failure handling" do
    input_file = File.join(fixtures_dir, "bank_account.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "bank_account_pbt.rb")
    config_file = File.join(output_dir, "bank_account_pbt_config.rb")
    impl_file = File.join(output_dir, "bank_account_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(impl_file, <<~RUBY)
      # frozen_string_literal: true

      class BankAccountImpl
        attr_reader :balance

        def initialize
          @balance = 0
        end

        def withdraw(amount)
          raise RangeError, "insufficient funds" if amount > @balance

          @balance -= amount
          @balance
        end
      end
    RUBY

    File.write(config_file, <<~RUBY)
      # frozen_string_literal: true

      BankAccountPbtConfig = {
        sut_factory: -> { BankAccountImpl.new },
        initial_state: 0,
        command_mappings: {
          withdraw_amount: {
            method: :withdraw,
            guard_failure_policy: :raise
          }
        },
        verify_context: {
          state_reader: ->(sut) { sut.balance }
        }
      }
    RUBY

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
        define_singleton_method(:nil) { nil }

        def self.integer(**_kwargs) = 1
        def self.string = "x"
        def self.array(value) = [value]
        def self.tuple(*values) = values

        def self.assert(worker:, num_runs:, seed:)
          raise "unexpected assert kwargs" unless worker == :none && num_runs == 5 && seed == 1

          yield
        end

        def self.stateful(model:, sut:, max_steps:, **extra)
          raise "unexpected Pbt.stateful kwargs: \#{extra.keys.inspect}" unless extra.empty?
          raise "unexpected max_steps" unless max_steps == 20

          state = model.initial_state
          command = model.commands(state).find { |candidate| candidate.name == :withdraw_amount }
          raise "withdraw_amount command missing" unless command

          args = command.arguments(state)
          raise "guard failure policy should keep command applicable" unless command.applicable?(state, args)

          instance = sut.call
          after_state = command.next_state(state, args)
          result = command.run!(instance, args)
          command.verify!(before_state: state, after_state: after_state, args: args, result: result, sut: instance)
        end
      end
    RUBY

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Generated scaffold with raising guard failure handling failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "supports config-driven custom guard failure handling via verify_override" do
    input_file = File.join(fixtures_dir, "bank_account.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "bank_account_pbt.rb")
    config_file = File.join(output_dir, "bank_account_pbt_config.rb")
    impl_file = File.join(output_dir, "bank_account_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(impl_file, <<~RUBY)
      # frozen_string_literal: true

      class BankAccountImpl
        attr_reader :balance

        def initialize
          @balance = 0
        end

        def withdraw(amount)
          return :rejected if amount > @balance

          @balance -= amount
          @balance
        end
      end
    RUBY

    File.write(config_file, <<~RUBY)
      # frozen_string_literal: true

      BankAccountPbtConfig = {
        sut_factory: -> { BankAccountImpl.new },
        initial_state: 0,
        command_mappings: {
          withdraw_amount: {
            method: :withdraw,
            guard_failure_policy: :custom,
            verify_override: ->(before_state:, after_state:, result:, observed_state:, guard_failed:, guard_failure_policy:, **) do
              raise "Expected custom guard failure path" unless guard_failed
              raise "Expected :custom policy" unless guard_failure_policy == :custom
              raise "Expected unchanged model state" unless after_state == before_state
              raise "Expected unchanged observed state" unless observed_state == after_state
              raise "Expected custom invalid-path result" unless result == :rejected
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { sut.balance }
        }
      }
    RUBY

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
        define_singleton_method(:nil) { nil }

        def self.integer(**_kwargs) = 1
        def self.string = "x"
        def self.array(value) = [value]
        def self.tuple(*values) = values

        def self.assert(worker:, num_runs:, seed:)
          raise "unexpected assert kwargs" unless worker == :none && num_runs == 5 && seed == 1

          yield
        end

        def self.stateful(model:, sut:, max_steps:, **extra)
          raise "unexpected Pbt.stateful kwargs: \#{extra.keys.inspect}" unless extra.empty?
          raise "unexpected max_steps" unless max_steps == 20

          state = model.initial_state
          command = model.commands(state).find { |candidate| candidate.name == :withdraw_amount }
          raise "withdraw_amount command missing" unless command

          args = command.arguments(state)
          raise "guard failure policy should keep command applicable" unless command.applicable?(state, args)

          instance = sut.call
          after_state = command.next_state(state, args)
          result = command.run!(instance, args)
          command.verify!(before_state: state, after_state: after_state, args: args, result: result, sut: instance)
        end
      end
    RUBY

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Generated scaffold with custom guard failure handling failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "fails with an actionable preflight error when Pbt.stateful is unavailable" do
    input_file = File.join(fixtures_dir, "stack.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "stack_pbt.rb")
    impl_file = File.join(output_dir, "stack_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(impl_file, <<~RUBY)
      # frozen_string_literal: true

      class StackImpl
      end
    RUBY

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
      end
    RUBY

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(false)
    expect(stdout + stderr).to include("Expected pbt >= #{SpecToPbt::PBT_STATEFUL_MIN_VERSION} with Pbt.stateful")
  end

  it "uses 0-arity arguments_override before inferred generators" do
    input_file = File.join(fixtures_dir, "stack.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "stack_pbt.rb")
    config_file = File.join(output_dir, "stack_pbt_config.rb")
    impl_file = File.join(output_dir, "stack_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(impl_file, <<~RUBY)
      # frozen_string_literal: true

      class StackImpl
        def initialize
          @values = []
        end

        def push(value)
          @values << value
          nil
        end

        def snapshot
          @values.dup
        end
      end
    RUBY

    File.write(config_file, <<~RUBY)
      # frozen_string_literal: true

      StackPbtConfig = {
        sut_factory: -> { StackImpl.new },
        command_mappings: {
          push_adds_element: {
            method: :push,
            arguments_override: -> { 7 }
          }
        },
        verify_context: {
          state_reader: ->(sut) { sut.snapshot }
        }
      }
    RUBY

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
        def self.integer = 1
        def self.nil = nil
        def self.assert(**)
          yield
        end

        def self.stateful(model:, sut:, **)
          state = model.initial_state
          command = model.commands(state).find { |candidate| candidate.name == :push_adds_element }
          raise "push_adds_element command missing" unless command

          args = command.arguments
          raise "Expected arguments_override to supply 7" unless args == 7

          instance = sut.call
          after_state = command.next_state(state, args)
          result = command.run!(instance, args)
          command.verify!(before_state: state, after_state: after_state, args: args, result: result, sut: instance)
        end
      end
    RUBY

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Generated scaffold with 0-arity arguments_override failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
  end

  it "uses 1-arity arguments_override for state-aware generators" do
    input_file = File.join(fixtures_dir, "partial_refund_remaining_capturable.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "partial_refund_remaining_capturable_pbt.rb")
    config_file = File.join(output_dir, "partial_refund_remaining_capturable_pbt_config.rb")
    impl_file = File.join(output_dir, "partial_refund_remaining_capturable_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(impl_file, <<~RUBY)
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
      end
    RUBY

    File.write(config_file, <<~RUBY)
      # frozen_string_literal: true

      PartialRefundRemainingCapturablePbtConfig = {
        sut_factory: -> { PartialRefundRemainingCapturableImpl.new(authorized: 20, captured: 0, refunded: 0) },
        initial_state: { authorized: 20, captured: 0, refunded: 0 },
        command_mappings: {
          capture: {
            method: :capture,
            arguments_override: ->(state) { state[:authorized] - 1 }
          }
        },
        verify_context: {
          state_reader: ->(sut) { { authorized: sut.authorized, captured: sut.captured, refunded: sut.refunded } }
        }
      }
    RUBY

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
        def self.integer(**_kwargs) = 1
        def self.assert(**)
          yield
        end

        def self.stateful(model:, sut:, **)
          state = model.initial_state
          command = model.commands(state).find { |candidate| candidate.name == :capture }
          raise "capture command missing" unless command

          args = command.arguments(state)
          raise "Expected state-aware arguments_override to use current state" unless args == 19

          instance = sut.call
          after_state = command.next_state(state, args)
          result = command.run!(instance, args)
          command.verify!(before_state: state, after_state: after_state, args: args, result: result, sut: instance)
        end
      end
    RUBY

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Generated scaffold with 1-arity arguments_override failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
  end

  it "compares observed state to the model by default when state_reader is configured" do
    input_file = File.join(fixtures_dir, "stack.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "stack_pbt.rb")
    config_file = File.join(output_dir, "stack_pbt_config.rb")
    impl_file = File.join(output_dir, "stack_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(impl_file, <<~RUBY)
      # frozen_string_literal: true

      class StackImpl
        def initialize
          @values = []
        end

        def push(value)
          @values << value
          nil
        end

        def snapshot
          []
        end
      end
    RUBY

    File.write(config_file, <<~RUBY)
      # frozen_string_literal: true

      StackPbtConfig = {
        sut_factory: -> { StackImpl.new },
        command_mappings: {
          push_adds_element: {
            method: :push
          }
        },
        verify_context: {
          state_reader: ->(sut) { sut.snapshot }
        }
      }
    RUBY

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
        def self.integer = 1
        def self.nil = nil
        def self.assert(**)
          yield
        end

        def self.stateful(model:, sut:, **)
          state = model.initial_state
          command = model.commands(state).find { |candidate| candidate.name == :push_adds_element }
          raise "push_adds_element command missing" unless command

          args = command.arguments
          instance = sut.call
          after_state = command.next_state(state, args)
          result = command.run!(instance, args)
          command.verify!(before_state: state, after_state: after_state, args: args, result: result, sut: instance)
        end
      end
    RUBY

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(false)
    expect(stdout + stderr).to include("Expected observed state to match model")
  end
end
