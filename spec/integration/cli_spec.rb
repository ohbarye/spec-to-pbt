# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"

RSpec.describe "CLI" do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:cli_path) { File.join(project_root, "bin/spec_to_pbt") }
  let(:fixtures_dir) { File.join(project_root, "spec/fixtures/alloy") }
  let(:output_dir) { File.join(project_root, "spec/tmp") }

  before do
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  describe "sort.als conversion" do
    let(:input_file) { File.join(fixtures_dir, "sort.als") }

    it "generates sort_pbt.rb" do
      stdout, stderr, status = Open3.capture3(cli_path, input_file, "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"
      expect(stdout).to include("Generated:")

      output_file = File.join(output_dir, "sort_pbt.rb")
      expect(File.exist?(output_file)).to be(true)

      content = File.read(output_file)
      expect(content).to include('require "pbt"')
      expect(content).to include('require_relative "sort_impl"')
      expect(content).to include("Pbt.assert")
      expect(content).to include('RSpec.describe "sort"')
    end

    it "generates check code for detected patterns" do
      _stdout, _stderr, _status = Open3.capture3(cli_path, input_file, "-o", output_dir)
      content = File.read(File.join(output_dir, "sort_pbt.rb"))

      # Invariant pattern should be detected for Sorted predicate
      expect(content).to include("Invariant failed")
      # Size pattern should be detected for LengthPreserved predicate
      expect(content).to include("Size failed")
    end
  end

  describe "stack.als conversion" do
    let(:input_file) { File.join(fixtures_dir, "stack.als") }

    it "generates stack_pbt.rb" do
      _stdout, stderr, status = Open3.capture3(cli_path, input_file, "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"

      output_file = File.join(output_dir, "stack_pbt.rb")
      expect(File.exist?(output_file)).to be(true)

      content = File.read(output_file)
      expect(content).to include('require_relative "stack_impl"')
      expect(content).to include('RSpec.describe "stack"')
    end

    it "generates check code for detected patterns" do
      _stdout, _stderr, _status = Open3.capture3(cli_path, input_file, "-o", output_dir)
      content = File.read(File.join(output_dir, "stack_pbt.rb"))

      # Size pattern for PushAddsElement
      expect(content).to include("Size failed")
      # Roundtrip pattern for PushPopIdentity
      expect(content).to include("Roundtrip failed")
    end

    it "comments unsupported patterns" do
      _stdout, _stderr, _status = Open3.capture3(cli_path, input_file, "-o", output_dir)
      content = File.read(File.join(output_dir, "stack_pbt.rb"))

      # IsEmpty predicate has only 'empty' pattern which is unsupported
      expect(content).to include("Unsupported patterns detected:")
    end
  end

  describe "stateful generation (--stateful)" do
    let(:input_file) { File.join(fixtures_dir, "stack.als") }

    it "generates stateful PBT scaffold code" do
      stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"
      expect(stdout).to include("Next: provide")
      expect(stdout).to include("require pbt >= #{SpecToPbt::PBT_STATEFUL_MIN_VERSION} with Pbt.stateful")
      expect(stdout).to include("install or update pbt")
      expect(stdout).to include("PBT_REPO_DIR")
      expect(stdout).not_to include("RUBYOPT=")

      output_file = File.join(output_dir, "stack_pbt.rb")
      expect(File.exist?(output_file)).to be(true)

      content = File.read(output_file)
      expect(content).to include("Pbt.stateful(")
      expect(content).to include("unless Pbt.respond_to?(:stateful)")
      expect(content).to include("class StackModel")
      expect(content).to include("worker: :none")
      expect(content).to include("Pbt.integer # placeholder for Element")
    end

    it "generates a companion config file with --with-config" do
      stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"
      expect(stdout).to include("Generated:")
      expect(stdout).to include("Next: edit")
      expect(stdout).to include("wire verify_context.state_reader first")
      expect(stdout).to include("arguments_override for out-of-range args or guard_failure_policy")

      config_file = File.join(output_dir, "stack_pbt_config.rb")
      expect(File.exist?(config_file)).to be(true)

      content = File.read(config_file)
      expect(content).to include("StackPbtConfig = {")
      expect(content).to include("sut_factory:")
      expect(content).to include("command_mappings:")
    end

    it "does not overwrite an existing config file" do
      config_file = File.join(output_dir, "stack_pbt_config.rb")
      File.write(config_file, "# user-owned config\n")

      stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"
      expect(stdout).to include("Preserved user-owned config:")
      expect(File.read(config_file)).to eq("# user-owned config\n")
    end
  end

  describe "Quint conversion" do
    let(:fixtures_dir) { File.join(project_root, "spec/fixtures/quint") }
    let(:input_file) { File.join(fixtures_dir, "counter.qnt") }
    let(:quint_fixture_dir) { File.join(project_root, "spec/fixtures/quint_json") }
    let(:fake_quint_path) { File.join(output_dir, "fake_quint") }

    before do
      script = <<~SH
        #!/bin/sh
        set -eu
        command="$1"
        input="$2"
        shift 2
        out=""
        while [ "$#" -gt 0 ]; do
          if [ "$1" = "--out" ]; then
            out="$2"
            shift 2
          else
            shift
          fi
        done
        base="$(basename "$input" .qnt)"
        cp "#{quint_fixture_dir}/${base}_${command}.json" "$out"
      SH
      File.write(fake_quint_path, script)
      FileUtils.chmod("+x", fake_quint_path)
    end

    it "auto-detects .qnt input and generates a stateful scaffold via the configured Quint CLI" do
      stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--quint-cli", fake_quint_path, "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"
      expect(stdout).to include("Generated:")
      expect(File.exist?(File.join(output_dir, "counter_pbt.rb"))).to be(true)
      expect(File.read(File.join(output_dir, "counter_pbt.rb"))).to include("class IncCommand")
    end

    it "supports explicit --frontend quint for stateless generation" do
      input_file = File.join(fixtures_dir, "normalize.qnt")
      stdout, stderr, status = Open3.capture3(cli_path, input_file, "--frontend", "quint", "--quint-cli", fake_quint_path, "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"
      expect(stdout).to include("Generated:")
      expect(File.read(File.join(output_dir, "normalize_pbt.rb"))).to include("result = normalize(input)")
    end

    it "auto-detects feature_flag_rollout.qnt and generates stateful Quint scaffold parity fixtures" do
      input_file = File.join(fixtures_dir, "feature_flag_rollout.qnt")
      stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--quint-cli", fake_quint_path, "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"
      expect(stdout).to include("Generated:")
      generated = File.read(File.join(output_dir, "feature_flag_rollout_pbt.rb"))
      expect(generated).to include("class EnableCommand")
      expect(generated).to include("class RolloutCommand")
    end

    it "supports explicit --frontend quint for job_queue_retry_dead_letter stateful generation" do
      input_file = File.join(fixtures_dir, "job_queue_retry_dead_letter.qnt")
      stdout, stderr, status = Open3.capture3(cli_path, input_file, "--frontend", "quint", "--stateful", "--quint-cli", fake_quint_path, "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"
      expect(stdout).to include("Generated:")
      generated = File.read(File.join(output_dir, "job_queue_retry_dead_letter_pbt.rb"))
      expect(generated).to include("class DispatchCommand")
      expect(generated).to include("class DeadLetterCommand")
    end
  end

  describe "error handling" do
    it "fails with missing input file" do
      _stdout, stderr, status = Open3.capture3(cli_path, "nonexistent.als")

      expect(status.success?).to be(false)
      expect(stderr).to include("File not found")
    end

    it "fails with no arguments" do
      _stdout, stderr, status = Open3.capture3(cli_path)

      expect(status.success?).to be(false)
      expect(stderr).to include("No input file")
    end

    it "fails when --with-config is used without --stateful" do
      input_file = File.join(fixtures_dir, "stack.als")
      _stdout, stderr, status = Open3.capture3(cli_path, input_file, "--with-config", "-o", output_dir)

      expect(status.success?).to be(false)
      expect(stderr).to include("--with-config is only supported with --stateful")
    end
  end

  describe "--help" do
    it "shows usage information" do
      stdout, _stderr, status = Open3.capture3(cli_path, "--help")

      expect(status.success?).to be(true)
      expect(stdout).to include("Usage:")
      expect(stdout).to include("--output")
      expect(stdout).to include("observed-state checks")
    end
  end

  describe "--version" do
    it "shows version" do
      stdout, _stderr, status = Open3.capture3(cli_path, "--version")

      expect(status.success?).to be(true)
      expect(stdout).to include("spec_to_pbt")
      expect(stdout).to include(SpecToPbt::VERSION)
    end
  end
end
