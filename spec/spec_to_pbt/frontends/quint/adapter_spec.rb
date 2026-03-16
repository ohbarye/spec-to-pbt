# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecToPbt::Frontends::Quint::Adapter do
  def load_quint_json(name, phase)
    path = File.expand_path("../../../fixtures/quint_json/#{name}_#{phase}.json", __dir__)
    JSON.parse(File.read(path))
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
