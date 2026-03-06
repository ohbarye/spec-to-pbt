# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"

RSpec.describe "Stateful generated scaffold E2E" do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:cli_path) { File.join(project_root, "bin/spec_to_pbt") }
  let(:fixtures_dir) { File.join(project_root, "spec/fixtures/alloy") }
  let(:output_dir) { File.join(project_root, "spec/tmp_stateful_e2e") }
  let(:pbt_repo_dir) { ENV.fetch("PBT_REPO_DIR", File.expand_path("../pbt", project_root)) }
  let(:pbt_lib_dir) { File.join(pbt_repo_dir, "lib") }

  before do
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  it "runs a generated stateful scaffold through Pbt.assert using the local ../pbt main checkout by default" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    input_file = File.join(fixtures_dir, "stack.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "stack_pbt.rb")
    impl_file = File.join(output_dir, "stack_impl.rb")

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

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{pbt_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Generated stateful scaffold execution failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "runs a config-aware stateful scaffold against a remapped Ruby API" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    input_file = File.join(fixtures_dir, "stack.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "stack_pbt.rb")
    config_file = File.join(output_dir, "stack_pbt_config.rb")
    impl_file = File.join(output_dir, "stack_impl.rb")

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

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{pbt_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Generated config-aware stateful scaffold execution failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end

  it "supports verify_override checks backed by state_reader" do
    unless Dir.exist?(pbt_repo_dir)
      skip "pbt repo not found at #{pbt_repo_dir} (set PBT_REPO_DIR to override)"
    end

    input_file = File.join(fixtures_dir, "stack.als")
    _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)
    expect(status.success?).to be(true), "CLI failed: #{stderr}"

    generated_spec = File.join(output_dir, "stack_pbt.rb")
    config_file = File.join(output_dir, "stack_pbt_config.rb")
    impl_file = File.join(output_dir, "stack_impl.rb")

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
              raise "Expected observed push state to match model" unless observed_state == after_state
            end
          },
          pop_removes_element: {
            method: :pop,
            verify_override: ->(after_state:, observed_state:) do
              raise "Expected observed pop state to match model" unless observed_state == after_state
            end
          }
        },
        verify_context: {
          state_reader: ->(sut) { sut.snapshot }
        }
      }
    RUBY

    env = {
      "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1",
      "RUBYOPT" => [ENV["RUBYOPT"], "-I#{pbt_lib_dir}"].compact.join(" ")
    }

    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", "rspec", generated_spec, chdir: project_root)

    expect(status.success?).to be(true), <<~MSG
      Generated config-aware scaffold with state_reader execution failed.
      STDOUT:
      #{stdout}
      STDERR:
      #{stderr}
    MSG
    expect(stdout).to include("1 example")
    expect(stdout).to include("0 failures")
  end
end
