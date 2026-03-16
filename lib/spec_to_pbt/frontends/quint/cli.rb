# frozen_string_literal: true

# rbs_inline: enabled

require "json"
require "open3"
require "tmpdir"

module SpecToPbt
  module Frontends
    module Quint
      class CLI
        # @rbs quint_cli: String?
        # @rbs which: ^(String) -> String?
        # @rbs capture3: untyped
        # @rbs return: void
        def initialize(quint_cli: nil, which: method(:default_which), capture3: Open3.method(:capture3))
          @quint_cli = quint_cli
          @which = which
          @capture3 = capture3
        end

        # @rbs return: Array[String]
        def resolved_command
          return [@quint_cli] if @quint_cli && !@quint_cli.empty?
          return ["quint"] if @which.call("quint")

          %w[npx --yes @informalsystems/quint]
        end

        # @rbs input_file: String
        # @rbs return: Hash[Symbol, Hash[String, untyped]]
        def load!(input_file)
          {
            parse: run_json!("parse", input_file),
            typecheck: run_json!("typecheck", input_file)
          }
        end

        private

        # @rbs subcommand: String
        # @rbs input_file: String
        # @rbs return: Hash[String, untyped]
        def run_json!(subcommand, input_file)
          Dir.mktmpdir("spec_to_pbt_quint") do |dir|
            out_path = File.join(dir, "#{subcommand}.json")
            command = resolved_command + [subcommand, input_file, "--out", out_path]

            stdout, stderr, status = @capture3.call(*command)
            unless status.success?
              raise SpecToPbt::FrontendError,
                    "quint #{subcommand} failed (exit #{status.exitstatus}): #{stderr.to_s.strip.empty? ? stdout : stderr}".strip
            end

            JSON.parse(File.read(out_path))
          rescue Errno::ENOENT => e
            raise SpecToPbt::FrontendError, "Unable to execute Quint CLI: #{e.message}"
          rescue JSON::ParserError => e
            raise SpecToPbt::FrontendError, "Quint CLI returned invalid JSON for #{subcommand}: #{e.message}"
          end
        end

        # @rbs command_name: String
        # @rbs return: String?
        def default_which(command_name)
          ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |segment|
            path = File.join(segment, command_name)
            return path if File.executable?(path) && !File.directory?(path)
          end

          nil
        end
      end
    end
  end
end
