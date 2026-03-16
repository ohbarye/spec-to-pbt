# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecToPbt::Frontends::Quint::CLI do
  let(:successful_status) { instance_double(Process::Status, success?: true, exitstatus: 0) }

  describe "#resolved_command" do
    it "prefers an explicit quint executable path" do
      cli = described_class.new(quint_cli: "/tmp/quint", which: ->(_name) { nil }, capture3: nil)

      expect(cli.resolved_command).to eq(["/tmp/quint"])
    end

    it "uses quint from PATH before falling back to npx" do
      cli = described_class.new(quint_cli: nil, which: ->(name) { name == "quint" ? "/usr/bin/quint" : nil }, capture3: nil)

      expect(cli.resolved_command).to eq(["quint"])
    end

    it "falls back to npx when quint is not on PATH" do
      cli = described_class.new(quint_cli: nil, which: ->(_name) { nil }, capture3: nil)

      expect(cli.resolved_command).to eq(%w[npx --yes @informalsystems/quint])
    end
  end

  describe "#load!" do
    it "runs parse and typecheck and returns both JSON payloads" do
      commands = []
      payloads = {
        "parse" => '{"stage":"parsing","errors":[]}',
        "typecheck" => '{"stage":"typechecking","errors":[]}'
      }
      cli = described_class.new(
        quint_cli: "/tmp/quint",
        which: ->(_name) { nil },
        capture3: lambda do |*command|
          commands << command
          out_path = command[command.index("--out") + 1]
          File.write(out_path, payloads.fetch(command[1]))
          ["", "", successful_status]
        end
      )

      result = cli.load!("/tmp/spec.qnt")

      expect(result[:parse]).to include("stage" => "parsing")
      expect(result[:typecheck]).to include("stage" => "typechecking")
      expect(commands.map { |command| command[1] }).to eq(%w[parse typecheck])
      expect(commands).to all(include("--out"))
    end

    it "raises a clear error when a subcommand fails" do
      failed_status = instance_double(Process::Status, success?: false, exitstatus: 17)
      cli = described_class.new(
        quint_cli: "/tmp/quint",
        which: ->(_name) { nil },
        capture3: ->(*_command) { ["", "boom", failed_status] }
      )

      expect { cli.load!("/tmp/spec.qnt") }
        .to raise_error(SpecToPbt::FrontendError, /quint parse failed/i)
    end

    it "raises a clear error when the CLI emits invalid JSON" do
      cli = described_class.new(
        quint_cli: "/tmp/quint",
        which: ->(_name) { nil },
        capture3: lambda do |*command|
          out_path = command[command.index("--out") + 1]
          File.write(out_path, "{not json")
          ["", "", successful_status]
        end
      )

      expect { cli.load!("/tmp/spec.qnt") }
        .to raise_error(SpecToPbt::FrontendError, /invalid JSON/i)
    end
  end
end
