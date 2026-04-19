# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"

RSpec.describe "Stateful invalid-path evaluation" do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:cli_path) { File.join(project_root, "bin/spec_to_pbt") }
  let(:fixtures_dir) { File.join(project_root, "spec/fixtures/alloy") }
  let(:output_dir) { File.join(project_root, "spec/tmp_stateful_invalid_path") }
  let(:stub_lib_dir) { File.join(output_dir, "stub_lib") }

  before do
    FileUtils.mkdir_p(output_dir)
    FileUtils.mkdir_p(stub_lib_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  it "recovers the partial_refund_remaining_capturable invalid refund survivor via arguments_override and guard_failure_policy" do
    input_file = File.join(fixtures_dir, "partial_refund_remaining_capturable.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "partial_refund_remaining_capturable_pbt.rb")
    config_file = File.join(output_dir, "partial_refund_remaining_capturable_pbt_config.rb")
    impl_file = File.join(output_dir, "partial_refund_remaining_capturable_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(config_file, <<~RUBY)
      # frozen_string_literal: true

      PartialRefundRemainingCapturablePbtConfig = {
        sut_factory: -> { PartialRefundRemainingCapturableImpl.new(authorized: 20, captured: 0, refunded: 0) },
        initial_state: { authorized: 20, captured: 0, refunded: 0 },
        command_mappings: {
          capture: { method: :capture },
          refund: {
            method: :refund,
            guard_failure_policy: :raise,
            arguments_override: ->(state) { Pbt.integer(min: state[:captured] + 1, max: state[:captured] + 1) }
          }
        },
        verify_context: {
          state_reader: ->(sut) { { authorized: sut.authorized, captured: sut.captured, refunded: sut.refunded } }
        }
      }
    RUBY

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

        def refund(amount)
          @captured -= amount
          @refunded += amount
          nil
        end
      end
    RUBY

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
        def self.integer(min:, max:) = max
        def self.assert(**)
          yield
        end

        def self.stateful(model:, sut:, **)
          state = model.initial_state
          command = model.commands(state).find { |candidate| candidate.name == :refund }
          raise "refund command missing" unless command

          args = command.arguments(state)
          raise "refund should be driven through the invalid path" unless command.applicable?(state, args)

          instance = sut.call
          after_state = command.next_state(state, args)
          result = command.run!(instance, args)
          command.verify!(before_state: state, after_state: after_state, args: args, result: result, sut: instance)
        end
      end
    RUBY

    env = {
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(false)
    expect(stdout + stderr).to include("Expected guard failure to surface as an exception")
  end

  it "recovers the connection_pool invalid checkin survivor via guard_failure_policy" do
    input_file = File.join(fixtures_dir, "connection_pool.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "connection_pool_pbt.rb")
    config_file = File.join(output_dir, "connection_pool_pbt_config.rb")
    impl_file = File.join(output_dir, "connection_pool_impl.rb")
    stub_pbt_file = File.join(stub_lib_dir, "pbt.rb")

    File.write(config_file, <<~RUBY)
      # frozen_string_literal: true

      ConnectionPoolPbtConfig = {
        sut_factory: -> { ConnectionPoolImpl.new(capacity: 3, available: 3, checked_out: 0) },
        initial_state: { available: 3, checked_out: 0, capacity: 3 },
        command_mappings: {
          checkout: { method: :checkout },
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

    File.write(impl_file, <<~RUBY)
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

    File.write(stub_pbt_file, <<~RUBY)
      # frozen_string_literal: true

      module Pbt
        def self.nil = nil
        def self.assert(**)
          yield
        end

        def self.stateful(model:, sut:, **)
          state = model.initial_state
          command = model.commands(state).find { |candidate| candidate.name == :checkin }
          raise "checkin command missing" unless command

          raise "guard failure policy should keep checkin applicable" unless command.applicable?(state)

          instance = sut.call
          after_state = command.next_state(state, nil)
          result = command.run!(instance, nil)
          command.verify!(before_state: state, after_state: after_state, args: nil, result: result, sut: instance)
        end
      end
    RUBY

    env = {
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{stub_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(false)
    expect(stdout + stderr).to include("Expected guard failure to surface as an exception")
  end
end
