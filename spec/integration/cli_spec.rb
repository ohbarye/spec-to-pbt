# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"

RSpec.describe "CLI" do
  let(:project_root) { File.expand_path("../..", __dir__) }
  let(:cli_path) { File.join(project_root, "bin/alloy_to_pbt") }
  let(:fixtures_dir) { File.join(project_root, "fixtures") }
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
      expect(content).to include("def sort(array)")
      expect(content).to include("Pbt.assert")
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
      expect(content).to include("class Stack")
      expect(content).to include("LIFO")
    end
  end

  describe "queue.als conversion" do
    let(:input_file) { File.join(fixtures_dir, "queue.als") }

    it "generates queue_pbt.rb" do
      _stdout, stderr, status = Open3.capture3(cli_path, input_file, "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"

      output_file = File.join(output_dir, "queue_pbt.rb")
      expect(File.exist?(output_file)).to be(true)

      content = File.read(output_file)
      expect(content).to include("class Queue")
      expect(content).to include("FIFO")
    end
  end

  describe "set.als conversion" do
    let(:input_file) { File.join(fixtures_dir, "set.als") }

    it "generates set_pbt.rb" do
      _stdout, stderr, status = Open3.capture3(cli_path, input_file, "-o", output_dir)

      expect(status.success?).to be(true), "CLI failed: #{stderr}"

      output_file = File.join(output_dir, "set_pbt.rb")
      expect(File.exist?(output_file)).to be(true)

      content = File.read(output_file)
      expect(content).to include("class MySet")
      expect(content).to include("union is commutative")
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
      expect(stdout).to include("alloy_to_pbt")
      expect(stdout).to include(AlloyToPbt::VERSION)
    end
  end
end
