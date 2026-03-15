# Product Evaluation TODO

## Objective

Reduce last-mile workflow friction in the current practical stateful workflow.

This pass is explicitly about:

- running existing complex in-repo domains
- editing only `*_pbt_config.rb` and `*_impl.rb`
- recording all friction immediately
- classifying friction before considering any generator promotion

This pass is not about:

- expanding Alloy coverage
- adding new domains first
- speculative promotion from a single domain

## Selected Trials

### Financial

- `partial_refund_remaining_capturable`
- fixture:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/spec/fixtures/alloy/partial_refund_remaining_capturable.als`

### Software-general

- `job_status_event_counters`
- fixture:
  - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/spec/fixtures/alloy/job_status_event_counters.als`

## Fixed Trial Sequence

Apply this sequence to each domain.

1. generate into a temporary output directory:
   - `bin/spec_to_pbt INPUT.als --stateful --with-config -o generated`
2. create only:
   - `generated/*_pbt_config.rb`
   - `generated/*_impl.rb`
3. do not edit:
   - `generated/*_pbt.rb`
4. run:
   - `ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD=1 bundle exec rspec generated/*_pbt.rb`
5. ensure `pbt >= 0.5.1` is installed so the generated scaffold can call `Pbt.stateful`
6. record every friction item immediately in:
   - `/Users/ohbarye/ghq/github.com/ohbarye/spec-to-pbt/docs/evaluation-friction-log-2026-03-13.md`

## Pass / Fail Rule

- editing generated `*_pbt.rb` counts as a product failure unless it is a confirmed generator bug
- if `*_pbt.rb` must be edited, classify it as:
  - `generator_bug`
  - or evidence that the current boundary statement is wrong

## Completion Checklist

- [x] financial trial complete
- [x] software trial complete
- [x] friction rows recorded
- [x] final classification written
- [x] promotion candidates evaluated

## Result Of This Pass

- both selected domains reached green without editing generated `*_pbt.rb`
- recurring friction was mostly:
  - stateful runtime setup (`Pbt.stateful` availability)
  - initial model-state baseline configuration
  - observed-state verification wiring
- no repeated structural friction justified generator promotion in this pass
