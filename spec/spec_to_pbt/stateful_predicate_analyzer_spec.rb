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

    context "with connection-pool transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/connection_pool.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "uses the guarded field for paired checkout/checkin updates" do
        checkout = analyzer.analyze(spec.predicates.find { |p| p.name == "Checkout" })
        checkin = analyzer.analyze(spec.predicates.find { |p| p.name == "Checkin" })

        expect(checkout.guard_kind).to eq(:non_empty)
        expect(checkout.state_field).to eq("available")
        expect(checkout.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["available", :decrement], ["checked_out", :increment]])
        expect(checkin.guard_kind).to eq(:non_empty)
        expect(checkin.state_field).to eq("checked_out")
        expect(checkin.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["available", :increment], ["checked_out", :decrement]])
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

    context "with authorization expiry/void transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/authorization_expiry_void.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "tracks paired authorization release updates" do
        authorize = analyzer.analyze(spec.predicates.find { |p| p.name == "Authorize" })
        void_op = analyzer.analyze(spec.predicates.find { |p| p.name == "Void" })
        expire = analyzer.analyze(spec.predicates.find { |p| p.name == "Expire" })

        expect(authorize.guard_kind).to eq(:arg_within_state)
        expect(authorize.state_field).to eq("available")
        expect(authorize.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["available", :decrement], ["held", :increment]])
        expect(void_op.guard_kind).to eq(:arg_within_state)
        expect(void_op.state_field).to eq("held")
        expect(void_op.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["available", :increment], ["held", :decrement]])
        expect(expire.guard_kind).to eq(:arg_within_state)
        expect(expire.state_field).to eq("held")
        expect(expire.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["available", :increment], ["held", :decrement]])
      end
    end

    context "with partial refund remaining-capturable transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/partial_refund_remaining_capturable.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "tracks capture/refund guards across three payment fields" do
        capture = analyzer.analyze(spec.predicates.find { |p| p.name == "Capture" })
        refund = analyzer.analyze(spec.predicates.find { |p| p.name == "Refund" })

        expect(capture.guard_kind).to eq(:arg_within_state)
        expect(capture.state_field).to eq("authorized")
        expect(capture.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["authorized", :decrement], ["captured", :increment]])
        expect(refund.guard_kind).to eq(:arg_within_state)
        expect(refund.state_field).to eq("captured")
        expect(refund.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["captured", :decrement], ["refunded", :increment]])
      end
    end

    context "with job queue retry/dead-letter transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/job_queue_retry_dead_letter.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "tracks ready/in_flight/dead_letter guards and updates" do
        dispatch = analyzer.analyze(spec.predicates.find { |p| p.name == "Dispatch" })
        ack = analyzer.analyze(spec.predicates.find { |p| p.name == "Ack" })
        retry_op = analyzer.analyze(spec.predicates.find { |p| p.name == "Retry" })
        dead_letter = analyzer.analyze(spec.predicates.find { |p| p.name == "DeadLetter" })

        expect(dispatch.guard_kind).to eq(:non_empty)
        expect(dispatch.state_field).to eq("ready")
        expect(dispatch.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["ready", :decrement], ["in_flight", :increment]])
        expect(ack.guard_kind).to eq(:non_empty)
        expect(ack.state_field).to eq("in_flight")
        expect(retry_op.guard_kind).to eq(:non_empty)
        expect(retry_op.state_field).to eq("in_flight")
        expect(retry_op.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["ready", :increment], ["in_flight", :decrement]])
        expect(dead_letter.guard_kind).to eq(:non_empty)
        expect(dead_letter.state_field).to eq("in_flight")
        expect(dead_letter.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to eq([["in_flight", :decrement], ["dead_letter", :increment]])
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

    context "with ledger projection transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/ledger_projection.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "prefers the append-only collection as state target while retaining projected scalar updates" do
        credit = analyzer.analyze(spec.predicates.find { |p| p.name == "PostCredit" })
        debit = analyzer.analyze(spec.predicates.find { |p| p.name == "PostDebit" })

        expect(credit.state_field).to eq("entries")
        expect(credit.state_field_multiplicity).to eq("seq")
        expect(credit.transition_kind).to eq(:append)
        expect(credit.state_update_shape).to eq(:append_like)
        expect(credit.command_confidence).to eq(:high)
        expect(credit.state_field_updates).to include(include(field: "balance", update_shape: :increment, rhs_source_kind: :arg))
        expect(credit.derived_verify_hints).to include(:check_projection_semantics)

        expect(debit.state_field).to eq("entries")
        expect(debit.state_field_multiplicity).to eq("seq")
        expect(debit.transition_kind).to eq(:append)
        expect(debit.state_update_shape).to eq(:append_like)
        expect(debit.command_confidence).to eq(:high)
        expect(debit.state_field_updates).to include(include(field: "balance", update_shape: :decrement, rhs_source_kind: :arg))
        expect(debit.derived_verify_hints).to include(:check_projection_semantics)
      end
    end

    context "with inventory projection transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/inventory_projection.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "treats a second append-only projection domain like the ledger pattern" do
        receive = analyzer.analyze(spec.predicates.find { |p| p.name == "Receive" })
        ship = analyzer.analyze(spec.predicates.find { |p| p.name == "Ship" })

        expect(receive.state_field).to eq("adjustments")
        expect(receive.state_field_multiplicity).to eq("seq")
        expect(receive.transition_kind).to eq(:append)
        expect(receive.state_update_shape).to eq(:append_like)
        expect(receive.command_confidence).to eq(:high)
        expect(receive.state_field_updates).to include(include(field: "stock", update_shape: :increment, rhs_source_kind: :arg))
        expect(receive.derived_verify_hints).to include(:check_projection_semantics)

        expect(ship.state_field).to eq("adjustments")
        expect(ship.state_field_multiplicity).to eq("seq")
        expect(ship.transition_kind).to eq(:append)
        expect(ship.state_update_shape).to eq(:append_like)
        expect(ship.command_confidence).to eq(:high)
        expect(ship.state_field_updates).to include(include(field: "stock", update_shape: :decrement, rhs_source_kind: :arg))
        expect(ship.derived_verify_hints).to include(:check_projection_semantics)
      end
    end

    context "with constant replacement transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/feature_flag_rollout.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "recognizes constant reset updates distinctly from arg/state-field replacement and bounded arg replacement" do
        disable = analyzer.analyze(spec.predicates.find { |p| p.name == "Disable" })
        enable = analyzer.analyze(spec.predicates.find { |p| p.name == "Enable" })
        rollout = analyzer.analyze(spec.predicates.find { |p| p.name == "Rollout" })

        expect(disable.state_field).to eq("rollout")
        expect(disable.rhs_source_kind).to eq(:constant)
        expect(disable.rhs_constant).to eq("0")
        expect(disable.state_update_shape).to eq(:replace_constant)

        expect(enable.rhs_source_kind).to eq(:state_field)
        expect(enable.rhs_source_field).to eq("max_rollout")
        expect(enable.state_update_shape).to eq(:replace_value)

        expect(rollout.state_field).to eq("rollout")
        expect(rollout.guard_kind).to eq(:arg_within_state)
        expect(rollout.guard_field).to eq("max_rollout")
        expect(rollout.rhs_source_kind).to eq(:arg)
        expect(rollout.state_update_shape).to eq(:replace_with_arg)
      end
    end

    context "with lifecycle status transitions" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/payment_status_lifecycle.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "recognizes scalar equality guards before constant replacements" do
        authorize = analyzer.analyze(spec.predicates.find { |p| p.name == "Authorize" })
        capture = analyzer.analyze(spec.predicates.find { |p| p.name == "Capture" })

        expect(authorize.state_field).to eq("status")
        expect(authorize.guard_kind).to eq(:state_equals_constant)
        expect(authorize.guard_field).to eq("status")
        expect(authorize.guard_constant).to eq("0")
        expect(authorize.rhs_source_kind).to eq(:constant)
        expect(authorize.rhs_constant).to eq("1")
        expect(authorize.state_update_shape).to eq(:replace_constant)

        expect(capture.guard_kind).to eq(:state_equals_constant)
        expect(capture.guard_field).to eq("status")
        expect(capture.guard_constant).to eq("1")
        expect(capture.rhs_constant).to eq("2")
        expect(capture.state_update_shape).to eq(:replace_constant)
      end
    end

    context "with lifecycle transitions plus counters" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/payment_status_counters.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "tracks constant status changes together with counter increments/decrements" do
        capture = analyzer.analyze(spec.predicates.find { |p| p.name == "CaptureOne" })
        reset = analyzer.analyze(spec.predicates.find { |p| p.name == "Reset" })

        expect(capture.guard_kind).to eq(:non_empty)
        expect(capture.guard_field).to eq("authorized")
        expect(capture.state_field_updates.map { |item| [item[:field], item[:update_shape]] }).to include(
          ["status", :replace_constant],
          ["authorized", :decrement],
          ["captured", :increment]
        )

        expect(reset.guard_kind).to eq(:state_equals_constant)
        expect(reset.guard_constant).to eq("2")
        expect(reset.state_field_updates.map { |item| [item[:field], item[:update_shape], item[:rhs_constant]] }).to include(
          ["status", :replace_constant, "0"],
          ["authorized", :replace_constant, "0"],
          ["captured", :replace_constant, "0"]
        )
      end
    end

    context "with lifecycle transitions plus amounts" do
      let(:source) { File.read(File.expand_path("../fixtures/alloy/payment_status_amounts.als", __dir__)) }
      let(:spec) { SpecToPbt::Parser.new.parse(source) }

      it "tracks constant status changes together with amount increments/decrements" do
        capture = analyzer.analyze(spec.predicates.find { |p| p.name == "CaptureAmount" })
        reset = analyzer.analyze(spec.predicates.find { |p| p.name == "Reset" })

        expect(capture.guard_kind).to eq(:arg_within_state)
        expect(capture.guard_field).to eq("authorized_amount")
        expect(capture.state_field_updates.map { |item| [item[:field], item[:update_shape], item[:rhs_source_kind]] }).to include(
          ["status", :replace_constant, :constant],
          ["authorized_amount", :decrement, :arg],
          ["captured_amount", :increment, :arg]
        )

        expect(reset.guard_kind).to eq(:state_equals_constant)
        expect(reset.guard_constant).to eq("2")
        expect(reset.state_field_updates.map { |item| [item[:field], item[:update_shape], item[:rhs_constant]] }).to include(
          ["status", :replace_constant, "0"],
          ["authorized_amount", :replace_constant, "0"],
          ["captured_amount", :replace_constant, "0"]
        )
      end
    end
  end
end
