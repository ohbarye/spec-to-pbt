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
      expect(stdout).to include("ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1")
      expect(stdout).to include("require pbt >= #{SpecToPbt::PBT_STATEFUL_MIN_VERSION} with Pbt.stateful")
      expect(stdout).to include("install or update pbt")
      expect(stdout).not_to include("RUBYOPT=")

      output_file = File.join(output_dir, "stack_pbt.rb")
      expect(File.exist?(output_file)).to be(true)

      content = File.read(output_file)
      expect(content).to include("Pbt.stateful(")
      expect(content).to include("unless Pbt.respond_to?(:stateful)")
      expect(content).to include("class StackModel")
      expect(content).to include("worker: :none")
      expect(content).to include('ENV["ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD"]')
      expect(content).to include("Pbt.integer # placeholder for Element")
    end

    it "generates a companion config file with --with-config" do
      stdout, stderr, status = Open3.capture3(cli_path, input_file, "--stateful", "--with-config", "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"
      expect(stdout).to include("Generated:")
      expect(stdout).to include("Next: edit")

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
