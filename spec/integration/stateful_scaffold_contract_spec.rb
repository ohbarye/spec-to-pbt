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
end
