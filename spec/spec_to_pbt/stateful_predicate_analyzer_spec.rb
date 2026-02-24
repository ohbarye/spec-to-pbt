# frozen_string_literal: true

require "spec_helper"

RSpec.describe SpecToPbt::StatefulPredicateAnalyzer do
  describe "#analyze" do
    let(:analyzer) { described_class.new(spec) }

    context "with stack predicates" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/stack.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "extracts state params, non-state args, and +1 size delta for push" do
        predicate = spec.predicates.find { |p| p.name == "PushAddsElement" }
        result = analyzer.analyze(predicate)

        expect(result.state_param_names).to eq(["s", "s'"])
        expect(result.state_type).to eq("Stack")
        expect(result.argument_params).to eq([{ name: "e", type: "Element" }])
        expect(result.size_delta).to eq(1)
        expect(result.requires_non_empty_state).to be(false)
      end

      it "extracts non-empty guard and -1 size delta for pop" do
        predicate = spec.predicates.find { |p| p.name == "PopRemovesElement" }
        result = analyzer.analyze(predicate)

        expect(result.state_param_names).to eq(["s", "s'"])
        expect(result.argument_params).to eq([])
        expect(result.size_delta).to eq(-1)
        expect(result.requires_non_empty_state).to be(true)
      end
    end

    context "with queue predicates" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/queue.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "extracts queue transitions similarly" do
        predicate = spec.predicates.find { |p| p.name == "Enqueue" }
        result = analyzer.analyze(predicate)

        expect(result.state_param_names).to eq(["q", "q'"])
        expect(result.state_type).to eq("Queue")
        expect(result.argument_params).to eq([{ name: "e", type: "Element" }])
        expect(result.size_delta).to eq(1)
      end
    end

    context "with primed state params on a non-module state signature" do
      let(:source) do
        <<~ALLOY
          module workflow

          sig Machine { value: one Int }
          sig Token {}

          pred Step[m, m': Machine, t: Token] {
            #m'.value = add[#m.value, 1]
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "infers state type from primed pair rather than module name" do
        predicate = spec.predicates.first
        result = analyzer.analyze(predicate)

        expect(result.state_param_names).to eq(["m", "m'"])
        expect(result.state_type).to eq("Machine")
        expect(result.argument_params).to eq([{ name: "t", type: "Token" }])
      end
    end
  end
end
