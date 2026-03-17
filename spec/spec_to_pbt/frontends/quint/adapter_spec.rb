# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecToPbt::Frontends::Quint::Adapter do
  def load_quint_json(name, phase)
    path = File.expand_path("../../../fixtures/quint_json/#{name}_#{phase}.json", __dir__)
    JSON.parse(File.read(path))
  end

  def scalar_guard_document(opcode:, threshold:)
    {
      "modules" => [
        {
          "name" => "guarded_counter",
          "declarations" => [
            { "kind" => "var", "id" => 1, "name" => "x", "typeAnnotation" => { "kind" => "int" } },
            {
              "kind" => "def",
              "name" => "Dec",
              "qualifier" => "action",
              "expr" => {
                "kind" => "app",
                "opcode" => "actionAll",
                "args" => [
                  {
                    "kind" => "app",
                    "opcode" => opcode,
                    "args" => [
                      { "kind" => "name", "name" => "x" },
                      { "kind" => "int", "value" => threshold }
                    ]
                  },
                  {
                    "kind" => "app",
                    "opcode" => "assign",
                    "args" => [
                      { "kind" => "name", "name" => "x" },
                      {
                        "kind" => "app",
                        "opcode" => "isub",
                        "args" => [
                          { "kind" => "name", "name" => "x" },
                          { "kind" => "int", "value" => 1 }
                        ]
                      }
                    ]
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  end

  describe "#adapt" do
    it "maps stateful Quint modules into a synthetic core state type and semantic hints" do
      document = described_class.new.adapt(
        parse_json: load_quint_json("counter", "parse"),
        typecheck_json: load_quint_json("counter", "typecheck")
      )

      expect(document).to be_a(SpecToPbt::Core::SpecDocument)
      expect(document.name).to eq("counter")
      expect(document.source_format).to eq(:quint)
      expect(document.metadata[:state_variables]).to eq([{ name: "x", type: "Int", multiplicity: "one" }])
      expect(document.metadata[:operation_name]).to be_nil

      state_type = document.types.find { |entity| entity.name == "CounterState" }
      expect(state_type.metadata[:category]).to eq(:module_state_type)
      expect(state_type.fields.map(&:name)).to eq(["x"])

      inc = document.properties.find { |entity| entity.name == "Inc" }
      expect(inc.params).to eq([])
      expect(inc.metadata.dig(:semantic_hints, :qualifier)).to eq(:action)
      expect(inc.metadata.dig(:semantic_hints, :state_type)).to eq("CounterState")
      expect(inc.metadata.dig(:semantic_hints, :state_updates)).to include(
        hash_including(field: "x", kind: :assignment, rhs_kind: :increment, rhs_constant: 1)
      )

      invariant = document.properties.find { |entity| entity.name == "NonNegative" }
      expect(invariant.metadata.dig(:semantic_hints, :qualifier)).to eq(:val)
      expect(invariant.metadata.dig(:semantic_hints, :property_category)).to eq(:invariant)
    end

    it "maps collection actions and guards into semantic hints" do
      document = described_class.new.adapt(
        parse_json: load_quint_json("list_counter", "parse"),
        typecheck_json: load_quint_json("list_counter", "typecheck")
      )

      enqueue = document.properties.find { |entity| entity.name == "Enqueue" }
      dequeue = document.properties.find { |entity| entity.name == "Dequeue" }

      expect(enqueue.params.map { |param| [param.name, param.type] }).to eq([["x", "Int"]])
      expect(enqueue.metadata.dig(:semantic_hints, :state_updates)).to include(
        hash_including(field: "items", rhs_kind: :append_arg, rhs_arg_name: "x")
      )
      expect(dequeue.metadata.dig(:semantic_hints, :guards)).to include(
        hash_including(kind: :non_empty, field: "items")
      )
      expect(dequeue.metadata.dig(:semantic_hints, :state_updates)).to include(
        hash_including(field: "items", rhs_kind: :remove_first)
      )
    end

    it "maps scalar positivity guards into semantic hints" do
      greater_than_zero = scalar_guard_document(opcode: "igt", threshold: 0)
      greater_or_equal_one = scalar_guard_document(opcode: "igte", threshold: 1)

      strict_document = described_class.new.adapt(parse_json: greater_than_zero, typecheck_json: greater_than_zero)
      inclusive_document = described_class.new.adapt(parse_json: greater_or_equal_one, typecheck_json: greater_or_equal_one)

      expect(strict_document.properties.find { |entity| entity.name == "Dec" }.metadata.dig(:semantic_hints, :guards)).to include(
        hash_including(kind: :non_empty, field: "x")
      )
      expect(inclusive_document.properties.find { |entity| entity.name == "Dec" }.metadata.dig(:semantic_hints, :guards)).to include(
        hash_including(kind: :non_empty, field: "x")
      )
    end

    it "maps bounded scalar replacement and sibling-field assignment for feature flag rollout" do
      document = described_class.new.adapt(
        parse_json: load_quint_json("feature_flag_rollout", "parse"),
        typecheck_json: load_quint_json("feature_flag_rollout", "typecheck")
      )

      expect(document.metadata[:state_variables]).to eq(
        [
          { name: "rollout", type: "Int", multiplicity: "one" },
          { name: "max_rollout", type: "Int", multiplicity: "one" }
        ]
      )

      enable = document.properties.find { |entity| entity.name == "Enable" }
      disable = document.properties.find { |entity| entity.name == "Disable" }
      rollout = document.properties.find { |entity| entity.name == "Rollout" }
      bounded = document.properties.find { |entity| entity.name == "RolloutBounded" }

      expect(enable.metadata.dig(:semantic_hints, :state_updates)).to include(
        hash_including(field: "rollout", rhs_kind: :replace_value, rhs_source_field: "max_rollout")
      )
      expect(disable.metadata.dig(:semantic_hints, :state_updates)).to include(
        hash_including(field: "rollout", rhs_kind: :replace_constant, rhs_constant: 0)
      )
      expect(rollout.params.map { |param| [param.name, param.type] }).to eq([["percent", "Int"]])
      expect(rollout.metadata.dig(:semantic_hints, :guards)).to include(
        hash_including(kind: :arg_within_state, field: "max_rollout")
      )
      expect(rollout.metadata.dig(:semantic_hints, :state_updates)).to include(
        hash_including(field: "rollout", rhs_kind: :replace_with_arg, rhs_arg_name: "percent")
      )
      expect(bounded.metadata.dig(:semantic_hints, :qualifier)).to eq(:val)
      expect(bounded.metadata.dig(:semantic_hints, :property_category)).to eq(:invariant)
    end

    it "maps multi-counter queue actions and guards into semantic hints" do
      document = described_class.new.adapt(
        parse_json: load_quint_json("job_queue_retry_dead_letter", "parse"),
        typecheck_json: load_quint_json("job_queue_retry_dead_letter", "typecheck")
      )

      expect(document.metadata[:state_variables]).to eq(
        [
          { name: "ready", type: "Int", multiplicity: "one" },
          { name: "in_flight", type: "Int", multiplicity: "one" },
          { name: "dead_letter", type: "Int", multiplicity: "one" }
        ]
      )

      dispatch = document.properties.find { |entity| entity.name == "Dispatch" }
      retry_action = document.properties.find { |entity| entity.name == "Retry" }
      dead_letter = document.properties.find { |entity| entity.name == "DeadLetter" }
      invariant = document.properties.find { |entity| entity.name == "NonNegativeReady" }

      expect(dispatch.metadata.dig(:semantic_hints, :guards)).to include(
        hash_including(kind: :non_empty, field: "ready")
      )
      expect(dispatch.metadata.dig(:semantic_hints, :state_updates)).to include(
        hash_including(field: "ready", rhs_kind: :decrement, rhs_constant: 1),
        hash_including(field: "in_flight", rhs_kind: :increment, rhs_constant: 1)
      )
      expect(retry_action.metadata.dig(:semantic_hints, :guards)).to include(
        hash_including(kind: :non_empty, field: "in_flight")
      )
      expect(retry_action.metadata.dig(:semantic_hints, :state_updates)).to include(
        hash_including(field: "ready", rhs_kind: :increment, rhs_constant: 1),
        hash_including(field: "in_flight", rhs_kind: :decrement, rhs_constant: 1)
      )
      expect(dead_letter.metadata.dig(:semantic_hints, :state_updates)).to include(
        hash_including(field: "in_flight", rhs_kind: :decrement, rhs_constant: 1),
        hash_including(field: "dead_letter", rhs_kind: :increment, rhs_constant: 1)
      )
      expect(invariant.metadata.dig(:semantic_hints, :property_category)).to eq(:invariant)
    end

    it "selects exactly one pure def as the stateless operation name" do
      document = described_class.new.adapt(
        parse_json: load_quint_json("normalize", "parse"),
        typecheck_json: load_quint_json("normalize", "typecheck")
      )

      expect(document.metadata[:operation_name]).to eq("normalize")
      expect(document.types).to be_empty
      expect(document.properties.map(&:name)).to eq(["Idempotent"])
    end

    it "rejects multiple pure defs in stateless Quint modules" do
      parse_json = {
        "modules" => [
          {
            "name" => "ambiguous",
            "declarations" => [
              { "kind" => "def", "name" => "first", "qualifier" => "puredef" },
              { "kind" => "def", "name" => "second", "qualifier" => "puredef" }
            ]
          }
        ]
      }

      expect do
        described_class.new.adapt(parse_json: parse_json, typecheck_json: parse_json)
      end.to raise_error(SpecToPbt::FrontendError, /exactly one pure top-level def/i)
    end

    it "rejects temporal properties in v1" do
      parse_json = {
        "modules" => [
          {
            "name" => "temporal_counter",
            "declarations" => [
              { "kind" => "var", "name" => "x", "typeAnnotation" => { "kind" => "int" } },
              { "kind" => "def", "name" => "AlwaysNonNegative", "qualifier" => "temporal" }
            ]
          }
        ]
      }

      expect do
        described_class.new.adapt(parse_json: parse_json, typecheck_json: parse_json)
      end.to raise_error(SpecToPbt::FrontendError, /temporal.*out of scope/i)
    end
  end
end
