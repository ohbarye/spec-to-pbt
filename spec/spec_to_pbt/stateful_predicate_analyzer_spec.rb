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
        expect(result.argument_params.map { |param| { name: param.name, type: param.type } }).to eq([{ name: "e", type: "Element" }])
        expect(result.size_delta).to eq(1)
        expect(result.requires_non_empty_state).to be(false)
        expect(result.state_field).to eq("elements")
        expect(result.transition_kind).to eq(:append)
        expect(result.state_update_shape).to eq(:append_like)
        expect(result.command_confidence).to eq(:high)
        expect(result.related_predicate_names).to eq(["PushPopIdentity", "IsEmpty", "LIFO"])
        expect(result.related_assertion_names).to eq(["StackProperties"])
        expect(result.derived_verify_hints).to include(:check_roundtrip_pairing, :check_empty_semantics, :check_ordering_semantics)
      end

      it "extracts non-empty guard and -1 size delta for pop" do
        predicate = spec.predicates.find { |p| p.name == "PopRemovesElement" }
        result = analyzer.analyze(predicate)

        expect(result.state_param_names).to eq(["s", "s'"])
        expect(result.argument_params).to eq([])
        expect(result.size_delta).to eq(-1)
        expect(result.requires_non_empty_state).to be(true)
        expect(result.guard_kind).to eq(:non_empty)
        expect(result.state_field).to eq("elements")
        expect(result.transition_kind).to eq(:pop)
        expect(result.result_position).to eq(:last)
        expect(result.state_update_shape).to eq(:remove_last)
        expect(result.derived_verify_hints).to include(:respect_non_empty_guard)
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
        expect(result.argument_params.map { |param| { name: param.name, type: param.type } }).to eq([{ name: "e", type: "Element" }])
        expect(result.size_delta).to eq(1)
        expect(result.state_field).to eq("elements")
        expect(result.transition_kind).to eq(:append)
        expect(result.state_update_shape).to eq(:append_like)
        expect(result.command_confidence).to eq(:high)
      end

      it "recognizes dequeue-like removal" do
        predicate = spec.predicates.find { |p| p.name == "Dequeue" }
        result = analyzer.analyze(predicate)

        expect(result.size_delta).to eq(-1)
        expect(result.requires_non_empty_state).to be(true)
        expect(result.state_field).to eq("elements")
        expect(result.transition_kind).to eq(:dequeue)
        expect(result.result_position).to eq(:first)
        expect(result.state_update_shape).to eq(:remove_first)
      end
    end

    context "with bounded queue predicates" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/bounded_queue.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "retains queue semantics while surfacing fullness-related sibling hints" do
        enqueue = analyzer.analyze(spec.predicates.find { |p| p.name == "Enqueue" })
        dequeue = analyzer.analyze(spec.predicates.find { |p| p.name == "Dequeue" })

        expect(enqueue.state_type).to eq("Queue")
        expect(enqueue.state_field).to eq("elements")
        expect(enqueue.transition_kind).to eq(:append)
        expect(enqueue.state_update_shape).to eq(:append_like)
        expect(enqueue.guard_kind).to eq(:below_capacity)
        expect(enqueue.related_predicate_names).to include("EnqueueDequeueIdentity", "IsEmpty", "IsFull")
        expect(enqueue.derived_verify_hints).to include(:respect_capacity_guard)
        expect(enqueue.related_assertion_names).to eq(["QueueBounds"])
        expect(dequeue.guard_kind).to eq(:non_empty)
        expect(dequeue.transition_kind).to eq(:dequeue)
        expect(dequeue.state_update_shape).to eq(:remove_first)
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
        expect(result.argument_params.map { |param| { name: param.name, type: param.type } }).to eq([{ name: "t", type: "Token" }])
        expect(result.state_field).to eq("value")
        expect(result.state_field_multiplicity).to eq("one")
        expect(result.transition_kind).to be_nil
        expect(result.scalar_update_kind).to eq(:increment_like)
        expect(result.state_update_shape).to eq(:increment)
      end
    end

    context "with size-preserving transition body" do
      let(:source) do
        <<~ALLOY
          module cache

          sig Cache { entries: seq Int }

          pred Rewrite[c, c': Cache] {
            #c'.entries = #c.entries
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "recognizes size_no_change transition hints" do
        result = analyzer.analyze(spec.predicates.first)

        expect(result.size_delta).to eq(0)
        expect(result.state_field).to eq("entries")
        expect(result.transition_kind).to eq(:size_no_change)
        expect(result.result_position).to be_nil
        expect(result.state_update_shape).to eq(:preserve_size)
        expect(result.command_confidence).to eq(:medium)
      end
    end

    context "with body-driven removal semantics but non-verb predicate names" do
      let(:source) do
        <<~ALLOY
          module bag

          sig Bag {
            elems: seq Int
          }

          pred TakeFront[b, b': Bag] {
            #b.elems > 0 implies #b'.elems = sub[#b.elems, 1]
          }

          pred DropLast[b, b': Bag] {
            #b.elems > 0 implies #b'.elems = sub[#b.elems, 1]
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "uses body+name hints to distinguish dequeue-like from pop-like removals" do
        take_front = analyzer.analyze(spec.predicates.find { |p| p.name == "TakeFront" })
        drop_last = analyzer.analyze(spec.predicates.find { |p| p.name == "DropLast" })

        expect(take_front.transition_kind).to eq(:dequeue)
        expect(take_front.result_position).to eq(:first)
        expect(take_front.command_confidence).to eq(:high)
        expect(take_front.state_update_shape).to eq(:remove_first)
        expect(drop_last.transition_kind).to eq(:pop)
        expect(drop_last.result_position).to eq(:last)
        expect(drop_last.command_confidence).to eq(:high)
        expect(drop_last.state_update_shape).to eq(:remove_last)
      end
    end

    context "with scalar replacement semantics" do
      let(:source) do
        <<~ALLOY
          module thermostat

          sig Thermostat {
            target: one Int
          }

          pred SetTarget[t, t': Thermostat, next: Int] {
            #t'.target = #next
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "recognizes direct replacement-style scalar updates" do
        result = analyzer.analyze(spec.predicates.first)

        expect(result.state_field).to eq("target")
        expect(result.scalar_update_kind).to eq(:replace_like)
        expect(result.rhs_source_kind).to eq(:arg)
        expect(result.state_update_shape).to eq(:replace_with_arg)
        expect(result.command_confidence).to eq(:medium)
      end
    end

    context "with arithmetic-style size transitions" do
      let(:source) do
        <<~ALLOY
          module arithmetic

          sig Counter {
            value: one Int
          }

          pred Inc[c, c': Counter] {
            #c'.value = #c.value + 1
          }

          pred Dec[c, c': Counter] {
            #c'.value = #c.value - 1
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "recognizes +1/-1 style transitions" do
        inc = analyzer.analyze(spec.predicates.find { |p| p.name == "Inc" })
        dec = analyzer.analyze(spec.predicates.find { |p| p.name == "Dec" })

        expect(inc.size_delta).to eq(1)
        expect(inc.scalar_update_kind).to eq(:increment_like)
        expect(inc.state_update_shape).to eq(:increment)
        expect(dec.size_delta).to eq(-1)
        expect(dec.scalar_update_kind).to eq(:decrement_like)
        expect(dec.state_update_shape).to eq(:decrement)
      end
    end

    context "with bank-account style scalar transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/bank_account.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "recognizes fixed and amount-based balance updates" do
        deposit = analyzer.analyze(spec.predicates.find { |p| p.name == "Deposit" })
        deposit_amount = analyzer.analyze(spec.predicates.find { |p| p.name == "DepositAmount" })
        withdraw = analyzer.analyze(spec.predicates.find { |p| p.name == "Withdraw" })
        withdraw_amount = analyzer.analyze(spec.predicates.find { |p| p.name == "WithdrawAmount" })

        expect(deposit.state_type).to eq("Account")
        expect(deposit.state_field).to eq("balance")
        expect(deposit.state_field_multiplicity).to eq("one")
        expect(deposit.scalar_update_kind).to eq(:increment_like)
        expect(deposit.state_update_shape).to eq(:increment)
        expect(deposit.related_predicate_names).to include("WithdrawAmount", "DepositWithdrawIdentity", "NonNegative")
        expect(deposit.derived_verify_hints).to include(:check_non_negative_scalar_state)
        expect(deposit_amount.argument_params.map { |param| { name: param.name, type: param.type } }).to eq([{ name: "amount", type: "Int" }])
        expect(deposit_amount.scalar_update_kind).to eq(:increment_like)
        expect(deposit_amount.rhs_source_kind).to eq(:arg)
        expect(deposit_amount.state_update_shape).to eq(:increment)
        expect(withdraw.guard_kind).to eq(:non_empty)
        expect(withdraw.scalar_update_kind).to eq(:decrement_like)
        expect(withdraw.state_update_shape).to eq(:decrement)
        expect(withdraw_amount.argument_params.map { |param| { name: param.name, type: param.type } }).to eq([{ name: "amount", type: "Int" }])
        expect(withdraw_amount.guard_kind).to eq(:arg_within_state)
        expect(withdraw_amount.scalar_update_kind).to eq(:decrement_like)
        expect(withdraw_amount.rhs_source_kind).to eq(:arg)
        expect(withdraw_amount.state_update_shape).to eq(:decrement)
        expect(withdraw_amount.derived_verify_hints).to include(:check_guard_failure_semantics)
        expect(withdraw.related_assertion_names).to eq(["AccountProperties"])
      end
    end

    context "with membership-oriented related properties" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/membership_queue.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "derives membership verify hints for append-like commands" do
        enqueue = analyzer.analyze(spec.predicates.find { |p| p.name == "Enqueue" })

        expect(enqueue.related_predicate_names).to include("EnqueueContains")
        expect(enqueue.related_pattern_hints).to include(:membership)
        expect(enqueue.derived_verify_hints).to include(:check_membership_semantics)
      end
    end

    context "with structured scalar replacement from a sibling state field" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/wallet_reset_limit.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "tracks the source field for replace-value updates" do
        result = analyzer.analyze(spec.predicates.find { |p| p.name == "ResetToLimit" })

        expect(result.state_field).to eq("balance")
        expect(result.rhs_source_kind).to eq(:state_field)
        expect(result.rhs_source_field).to eq("credit_limit")
        expect(result.state_update_shape).to eq(:replace_value)
      end
    end

    context "with hold/capture/release reservation transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/hold_capture_release.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "tracks multiple scalar field updates for hold/release" do
        hold = analyzer.analyze(spec.predicates.find { |p| p.name == "Hold" })
        release = analyzer.analyze(spec.predicates.find { |p| p.name == "Release" })
        capture = analyzer.analyze(spec.predicates.find { |p| p.name == "Capture" })

        expect(hold.guard_kind).to eq(:arg_within_state)
        expect(hold.state_field).to eq("available")
        expect(hold.derived_verify_hints).to include(:check_guard_failure_semantics)
        expect(hold.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["available", :decrement], ["held", :increment]])
        expect(release.guard_kind).to eq(:arg_within_state)
        expect(release.state_field).to eq("held")
        expect(release.derived_verify_hints).to include(:check_guard_failure_semantics)
        expect(release.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["available", :increment], ["held", :decrement]])
        expect(capture.guard_kind).to eq(:arg_within_state)
        expect(capture.state_field).to eq("held")
        expect(capture.derived_verify_hints).to include(:check_guard_failure_semantics)
        expect(capture.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["held", :decrement]])
      end
    end

    context "with transfer-between-accounts transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/transfer_between_accounts.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "tracks paired decrement/increment updates across multiple balance fields" do
        transfer = analyzer.analyze(spec.predicates.find { |p| p.name == "Transfer" })

        expect(transfer.guard_kind).to eq(:arg_within_state)
        expect(transfer.state_field).to eq("source_balance")
        expect(transfer.derived_verify_hints).to include(:check_guard_failure_semantics)
        expect(transfer.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["source_balance", :decrement], ["target_balance", :increment]])
      end
    end

    context "with refund/reversal settlement transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/refund_reversal.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "tracks paired refund/reversal field updates" do
        refund = analyzer.analyze(spec.predicates.find { |p| p.name == "Refund" })
        reverse = analyzer.analyze(spec.predicates.find { |p| p.name == "Reverse" })

        expect(refund.guard_kind).to eq(:arg_within_state)
        expect(refund.state_field).to eq("captured")
        expect(refund.derived_verify_hints).to include(:check_guard_failure_semantics)
        expect(refund.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["captured", :decrement], ["refunded", :increment]])
        expect(reverse.guard_kind).to eq(:arg_within_state)
        expect(reverse.state_field).to eq("refunded")
        expect(reverse.derived_verify_hints).to include(:check_guard_failure_semantics)
        expect(reverse.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["captured", :increment], ["refunded", :decrement]])
      end
    end

    context "with scalar replacement without # prefix on rhs" do
      let(:source) do
        <<~ALLOY
          module thermostat

          sig Thermostat {
            target: one Int
          }

          pred SetTarget[t, t': Thermostat, next: Int] {
            #t'.target = next
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "still treats rhs assignment as replace-like" do
        result = analyzer.analyze(spec.predicates.first)

        expect(result.scalar_update_kind).to eq(:replace_like)
        expect(result.rhs_source_kind).to eq(:arg)
        expect(result.state_update_shape).to eq(:replace_with_arg)
      end
    end

    context "with weak transition evidence only" do
      let(:source) do
        <<~ALLOY
          module weak

          sig Box {
            value: one Int
          }

          pred MaybeChange[b, b': Box] {
            b' = b
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "marks the predicate as low-confidence for command extraction" do
        result = analyzer.analyze(spec.predicates.first)

        expect(result.command_confidence).to eq(:low)
        expect(result.state_update_shape).to eq(:unknown)
      end
    end

    context "with scalar no-op preservation" do
      let(:source) do
        <<~ALLOY
          module noop

          sig Box {
            value: one Int
          }

          pred Keep[b, b': Box] {
            #b'.value = #b.value
          }
        ALLOY
      end
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "distinguishes preserve-value updates from replacement" do
        result = analyzer.analyze(spec.predicates.first)

        expect(result.rhs_source_kind).to eq(:state_field)
        expect(result.state_update_shape).to eq(:preserve_value)
        expect(result.command_confidence).to eq(:medium)
      end
    end
  end
end
