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
